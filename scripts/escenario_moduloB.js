// ------------------------------------------------------------------
// _compat.js — Funciones auxiliares comunes a todos los scripts de Remix
// ------------------------------------------------------------------
// Remix no permite importar fácilmente un script desde otro, así que
// este bloque se COPIA al principio de cada script. Está aquí como
// referencia única: si se corrige algo, copiarlo de nuevo a los demás.
//
// Funciona con ethers v5 y v6 (según la versión que traiga Remix).
// Requisitos en Remix:
//   1. Entorno «Remix VM» seleccionado en «Deploy & Run Transactions».
//   2. Compilar ANTES los contratos que el script despliega.
//   3. En Ajustes (Settings) > «Generate contract metadata» ACTIVADO,
//      para que Remix cree las carpetas artifacts/.
// ------------------------------------------------------------------

// ethers está disponible como global en los scripts de Remix; si no, se importa.
const E = (typeof ethers !== 'undefined') ? ethers : require('ethers')
const V6 = typeof E.BrowserProvider === 'function'
const U = V6 ? E : E.utils

const proveedor = V6
  ? new E.BrowserProvider(web3Provider)
  : new E.providers.Web3Provider(web3Provider)

const cuenta = async (i) => await proveedor.getSigner(i)
const direccionDe = async (c) => (typeof c.getAddress === 'function' ? await c.getAddress() : c.address)
const abiCoder = V6 ? E.AbiCoder.defaultAbiCoder() : E.utils.defaultAbiCoder
const id = (texto) => U.keccak256(U.toUtf8Bytes(texto)) // equivale a keccak256("texto")

// Busca el artefacto compilado en las rutas habituales de Remix
async function artefacto (nombre, carpeta) {
  const rutas = [
    `${carpeta}/artifacts/${nombre}.json`,
    `contracts/artifacts/${nombre}.json`,
    `artifacts/${nombre}.json`
  ]
  for (const r of rutas) {
    try {
      const txt = await remix.call('fileManager', 'getFile', r)
      if (txt) return JSON.parse(txt)
    } catch (e) { /* probar la siguiente ruta */ }
  }
  throw new Error(`No encuentro el artefacto de ${nombre}. ¿Lo compilaste? ¿Está activado «Generate contract metadata»?`)
}

// Despliega un contrato y devuelve [instancia, gasUsado]
async function desplegar (nombre, carpeta, args = [], firmante = null) {
  const art = await artefacto(nombre, carpeta)
  const f = firmante || await cuenta(0)
  const fabrica = new E.ContractFactory(art.abi, art.data.bytecode.object, f)
  const c = await fabrica.deploy(...args)
  const tx = V6 ? c.deploymentTransaction() : c.deployTransaction
  const rc = await tx.wait()
  console.log(`✔ ${nombre} desplegado en ${await direccionDe(c)} — gas: ${rc.gasUsed.toString()}`)
  return [c, rc.gasUsed.toString()]
}

// Envía una transacción y devuelve el gas usado
async function enviar (etiqueta, promesaTx, tablaGas) {
  const tx = await promesaTx
  const rc = await tx.wait()
  const gas = rc.gasUsed.toString()
  console.log(`  · ${etiqueta} — gas: ${gas}`)
  if (tablaGas) tablaGas.push({ operacion: etiqueta, gas })
  return rc
}

// Comprueba que una llamada revierte
async function debeRevertir (etiqueta, promesa) {
  try {
    const tx = await promesa
    if (tx && tx.wait) await tx.wait()
    console.log(`  ✘ ${etiqueta}: NO revirtió y debía hacerlo`)
  } catch (e) {
    console.log(`  ✔ ${etiqueta}: revierte como se espera`)
  }
}

// ==================================================================
// escenario_moduloB.js — Curso B
// Despliega RegistroTitulos contra el simulacro del registro de emisores,
// emite títulos individuales y en lote, prueba los controles de seguridad,
// el ciclo de vida, la rectificación y la pausa, e informa del gas.
// Compilar antes: SimRegistroEmisores, RegistroTitulos
// ==================================================================
;(async () => {
  try {
    const gas = []
    const [admin, emisorIng, emisorSal] = await Promise.all([0, 1, 2].map(cuenta))
    const [dAdmin, dIng, dSal] = await Promise.all([admin, emisorIng, emisorSal].map(direccionDe))
    const ING = id('ING'); const SAL = id('SAL')
    const INF = id('ING-INFORMATICA'); const ENF = id('SAL-ENFERMERIA')
    const L = (s) => U.hexlify(U.toUtf8Bytes(s)) // localizador -> bytes10
    const comp = (n) => U.keccak256(U.toUtf8Bytes(`compromiso-de-prueba-${n}`)) // en real: Módulo C

    console.log('— Despliegue —')
    const [reg] = await desplegar('SimRegistroEmisores', 'contracts/simulacros')
    const [tit, gTit] = await desplegar('RegistroTitulos', 'contracts/moduloB', [await direccionDe(reg), dAdmin])
    gas.push({ operacion: 'desplegar RegistroTitulos', gas: gTit })
    await enviar('autorizar emisor ING (simulacro)', reg.autorizarEmisor(dIng, ING))
    await enviar('autorizar emisor SAL (simulacro)', reg.autorizarEmisor(dSal, SAL))

    console.log('— Emisión individual —')
    await enviar('emitir U0ZSA8QPFN (ING)', tit.connect(emisorIng).emitir(L('U0ZSA8QPFN'), ING, INF, comp(1)), gas)
    await enviar('emitir K7M2Q9XR4T (SAL)', tit.connect(emisorSal).emitir(L('K7M2Q9XR4T'), SAL, ENF, comp(2)), gas)

    console.log('— Emisión en lote —')
    for (const n of [5, 20, 50]) {
      const locs = Array.from({ length: n }, (_, i) => L('LOTE' + String(n).padStart(2, '0') + String(i).padStart(4, '0')))
      const comps = locs.map((_, i) => comp(1000 * n + i))
      const rc = await enviar(`emitir lote de ${n}`, tit.connect(emisorIng).emitirLote(locs, ING, INF, comps), gas)
      console.log(`    gas por título en el lote de ${n}: ${Math.round(Number(rc.gasUsed) / n)}`)
    }

    console.log('— Controles de seguridad —')
    await debeRevertir('localizador repetido', tit.connect(emisorIng).emitir(L('U0ZSA8QPFN'), ING, INF, comp(9)))
    await debeRevertir('localizador en minúsculas', tit.connect(emisorIng).emitir(L('u0zsa8qpfn'), ING, INF, comp(9)))
    await debeRevertir('compromiso vacío', tit.connect(emisorIng).emitir(L('ZZZZZZZZZZ'), ING, INF, '0x' + '00'.repeat(32)))
    await debeRevertir('emisor SAL emite en ING', tit.connect(emisorSal).emitir(L('ZZZZZZZZZZ'), ING, INF, comp(9)))
    await debeRevertir('emisor SAL revoca título de ING', tit.connect(emisorSal).revocar(L('U0ZSA8QPFN'), 1))
    await debeRevertir('lote con duplicado interno',
      tit.connect(emisorIng).emitirLote([L('DUP0000001'), L('DUP0000001')], ING, INF, [comp(7), comp(8)]))
    await debeRevertir('lote con largos distintos', tit.connect(emisorIng).emitirLote([L('AAAA000001')], ING, INF, []))

    console.log('— Ciclo de vida y rectificación —')
    await enviar('suspender U0ZSA8QPFN', tit.connect(emisorIng).suspender(L('U0ZSA8QPFN'), 5), gas)
    await enviar('reactivar U0ZSA8QPFN', tit.connect(emisorIng).reactivar(L('U0ZSA8QPFN')), gas)
    await enviar('rectificar U0ZSA8QPFN -> H5J2W7P9D4', tit.connect(emisorIng).rectificar(L('U0ZSA8QPFN'), L('H5J2W7P9D4'), comp(3)), gas)
    await debeRevertir('reactivar un rectificado', tit.connect(emisorIng).reactivar(L('U0ZSA8QPFN')))

    console.log('— Pausa de emergencia —')
    await debeRevertir('un emisor intenta pausar', tit.connect(emisorIng).pausar())
    await enviar('pausar (administración)', tit.connect(admin).pausar(), gas)
    await debeRevertir('emitir en pausa', tit.connect(emisorIng).emitir(L('PAUSA00001'), ING, INF, comp(4)))
    await enviar('revocar en pausa (permitido)', tit.connect(emisorSal).revocar(L('K7M2Q9XR4T'), 2), gas)
    await enviar('reanudar', tit.connect(admin).reanudar(), gas)

    const ESTADOS = ['Inexistente', 'Emitido', 'Suspendido', 'Revocado']
    for (const loc of ['U0ZSA8QPFN', 'H5J2W7P9D4', 'K7M2Q9XR4T']) {
      const t = await tit.obtenerTitulo(L(loc))
      const rect = t.rectificadoComo === '0x' + '00'.repeat(10) ? '-' : U.toUtf8String(t.rectificadoComo)
      console.log(`  ${loc}: ${ESTADOS[Number(t.estado)]}, motivo ${t.motivo}, rectificadoComo ${rect}`)
    }
    console.log(`  total de títulos: ${await tit.totalTitulos()}`)
    await debeRevertir('lote de 51 (supera MAX_LOTE)', tit.connect(emisorIng).emitirLote(Array.from({ length: 51 }, (_, i) => L('MAX51' + String(i).padStart(5, '0'))), ING, INF, Array.from({ length: 51 }, (_, i) => comp(9000 + i))))
    console.log('  Compara en la tabla el gas por título: individual frente a lotes de 5, 20 y 50.')

    console.log('— Tabla de gas —'); console.table(gas)
  } catch (e) {
    console.error(e.message || e)
  }
})()
