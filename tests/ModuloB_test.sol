// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/moduloB/RegistroTitulos.sol";
import "../contracts/simulacros/SimRegistroEmisores.sol";
import "../contracts/comun/ActorPruebas.sol";
import "../contracts/comun/ConstantesUBO.sol";

/// @title Pruebas del Módulo B — RegistroTitulos
/// @notice Usa SimRegistroEmisores en lugar del registro real del Curso A.
///         El propio contrato de prueba actúa como `administracion` (para la pausa).
///         9 pruebas: emisión, formato, permisos, lotes, ciclo de vida, rectificación y pausa.
contract ModuloBTest {
    SimRegistroEmisores registro;
    RegistroTitulos titulos;
    ActorPruebas emisorIng;
    ActorPruebas emisorSal;
    bytes32 constant PROGRAMA = keccak256("ING-INFORMATICA");
    bytes32 constant COMPROMISO = bytes32(uint256(0x1234));
    bytes10 constant L1 = bytes10("U0ZSA8QPFN");
    bytes10 constant L2 = bytes10("K7M2Q9XR4T");
    bytes10 constant L3 = bytes10("B3N8V1C6Z0");

    function beforeEach() public {
        registro = new SimRegistroEmisores();
        titulos = new RegistroTitulos(address(registro), address(this));
        emisorIng = new ActorPruebas();
        emisorSal = new ActorPruebas();
        registro.autorizarEmisor(address(emisorIng), ConstantesUBO.ING);
        registro.autorizarEmisor(address(emisorSal), ConstantesUBO.SAL);
    }

    function _emitir(ActorPruebas quien, bytes10 loc, bytes32 facultad) internal {
        quien.llamar(address(titulos),
            abi.encodeCall(IRegistroTitulos.emitir, (loc, facultad, PROGRAMA, COMPROMISO)));
    }

    // Ayudante: hace una llamada que DEBE funcionar (si falla, la prueba falla)
    function _ejecutar(ActorPruebas quien, bytes memory datos) internal {
        quien.llamar(address(titulos), datos);
    }

    // Ayudante: devuelve true si la llamada FALLA (que es lo que queremos en varias pruebas)
    function _revierte(ActorPruebas quien, bytes memory datos) internal returns (bool) {
        return !quien.intentar(address(titulos), datos);
    }

    // Emitir guarda el título con sus datos
    function emisionCorrecta() public {
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        IRegistroTitulos.Titulo memory t = titulos.obtenerTitulo(L1);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Emitido), "Estado inicial");
        Assert.equal(t.compromiso, COMPROMISO, "Compromiso guardado");
        Assert.equal(t.emisor, address(emisorIng), "Emisor registrado");
        Assert.equal(titulos.totalTitulos(), 1, "Contador");
    }

    // Un localizador ya usado no se puede volver a usar
    function localizadorRepetidoRevierte() public {
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        try emisorIng.llamar(address(titulos),
            abi.encodeCall(IRegistroTitulos.emitir, (L1, ConstantesUBO.ING, PROGRAMA, bytes32(uint256(9)))))
        {
            Assert.ok(false, "Un localizador no puede reutilizarse");
        } catch {
            Assert.equal(titulos.obtenerTitulo(L1).compromiso, COMPROMISO, "No se sobrescribe");
        }
    }

    // ---------- PRUEBAS OBLIGATORIAS ----------

    // Un localizador mal escrito no se acepta
    function localizadorConFormatoInvalido() public {
        bytes10[3] memory malos = [
            bytes10("u0zsa8qpfn"), // minúsculas
            bytes10("ABC"),        // muy corto (Solidity lo rellena con ceros)
            bytes10("U0ZSA8-PFN")  // tiene un guion en medio
        ];

        for (uint256 i = 0; i < 3; i++) {
            bool fallo = _revierte(emisorIng,
                abi.encodeCall(IRegistroTitulos.emitir, (malos[i], ConstantesUBO.ING, PROGRAMA, COMPROMISO)));
            Assert.ok(fallo, "Un localizador mal escrito debe rechazarse");
        }
        Assert.equal(titulos.totalTitulos(), 0, "No se debe guardar nada");

        // Y uno bien escrito sí pasa
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        Assert.equal(titulos.totalTitulos(), 1, "El localizador correcto si se guarda");
    }

    // Alguien de otra facultad no puede tocar los títulos de Ingeniería
    function emisorDeOtraFacultad() public {
        // El emisor de Salud intenta emitir en Ingeniería: debe fallar
        bool emitirFallo = _revierte(emisorSal,
            abi.encodeCall(IRegistroTitulos.emitir, (L1, ConstantesUBO.ING, PROGRAMA, COMPROMISO)));
        Assert.ok(emitirFallo, "Salud no puede emitir en Ingenieria");

        // El emisor de Ingeniería emite bien un título
        _emitir(emisorIng, L1, ConstantesUBO.ING);

        // El emisor de Salud intenta revocarlo y suspenderlo: debe fallar
        bool revocarFallo = _revierte(emisorSal,
            abi.encodeCall(IRegistroTitulos.revocar, (L1, ConstantesUBO.MOTIVO_FRAUDE)));
        Assert.ok(revocarFallo, "Salud no puede revocar un titulo de Ingenieria");

        bool suspenderFallo = _revierte(emisorSal,
            abi.encodeCall(IRegistroTitulos.suspender, (L1, ConstantesUBO.MOTIVO_EN_INVESTIGACION)));
        Assert.ok(suspenderFallo, "Salud no puede suspender un titulo de Ingenieria");

        // El título sigue Emitido, sin cambios
        Assert.equal(
            uint256(titulos.obtenerTitulo(L1).estado),
            uint256(IRegistroTitulos.Estado.Emitido),
            "El titulo no debe cambiar"
        );
    }

    // Un lote bueno registra todo; un lote con un repetido no registra nada
    function loteCorrectoYTodoONada() public {
        // Lote bueno de 3 títulos
        bytes10[] memory locs = new bytes10[](3);
        locs[0] = L1;
        locs[1] = L2;
        locs[2] = L3;
        bytes32[] memory comps = new bytes32[](3);
        comps[0] = bytes32(uint256(1));
        comps[1] = bytes32(uint256(2));
        comps[2] = bytes32(uint256(3));

        _ejecutar(emisorIng, abi.encodeWithSelector(
            IRegistroTitulos.emitirLote.selector, locs, ConstantesUBO.ING, PROGRAMA, comps));
        Assert.equal(titulos.totalTitulos(), 3, "El lote bueno registra los 3");

        // Lote malo: el primer localizador se repite al final
        bytes10 a = bytes10("A1B2C3D4E5");
        bytes10 b = bytes10("F6G7H8I9J0");
        bytes10[] memory locsMalos = new bytes10[](3);
        locsMalos[0] = a;
        locsMalos[1] = b;
        locsMalos[2] = a; // repetido dentro del mismo lote

        bool fallo = _revierte(emisorIng, abi.encodeWithSelector(
            IRegistroTitulos.emitirLote.selector, locsMalos, ConstantesUBO.ING, PROGRAMA, comps));
        Assert.ok(fallo, "Un lote con un repetido debe fallar");

        // Todo o nada: no se guardó ninguno de los tres, ni siquiera los buenos
        Assert.equal(titulos.totalTitulos(), 3, "El contador no cambia");
        Assert.equal(
            uint256(titulos.obtenerTitulo(a).estado),
            uint256(IRegistroTitulos.Estado.Inexistente),
            "El primero no debe quedar guardado"
        );
        Assert.equal(
            uint256(titulos.obtenerTitulo(b).estado),
            uint256(IRegistroTitulos.Estado.Inexistente),
            "El segundo no debe quedar guardado"
        );
    }

    // Lotes mal armados: largos distintos, vacío y demasiado grande
    function loteInvalido() public {
        // 1. Largos distintos: 2 localizadores y 1 compromiso
        bytes10[] memory dosLocs = new bytes10[](2);
        dosLocs[0] = L1;
        dosLocs[1] = L2;
        bytes32[] memory unComp = new bytes32[](1);
        unComp[0] = COMPROMISO;
        bool falloLargos = _revierte(emisorIng, abi.encodeWithSelector(
            IRegistroTitulos.emitirLote.selector, dosLocs, ConstantesUBO.ING, PROGRAMA, unComp));
        Assert.ok(falloLargos, "Largos distintos deben fallar");

        // 2. Lote vacío
        bytes10[] memory vacioLocs = new bytes10[](0);
        bytes32[] memory vacioComps = new bytes32[](0);
        bool falloVacio = _revierte(emisorIng, abi.encodeWithSelector(
            IRegistroTitulos.emitirLote.selector, vacioLocs, ConstantesUBO.ING, PROGRAMA, vacioComps));
        Assert.ok(falloVacio, "Un lote vacio debe fallar");

        // 3. Lote con un título de más que el máximo
        uint256 n = ConstantesUBO.MAX_LOTE + 1;
        bytes10[] memory muchosLocs = new bytes10[](n);
        bytes32[] memory muchosComps = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            bytes memory b = bytes("U0ZSA8QP00");
            b[8] = bytes1(uint8(48 + i / 10));   // decena
            b[9] = bytes1(uint8(48 + (i % 10))); // unidad
            muchosLocs[i] = bytes10(b);
            muchosComps[i] = bytes32(i + 1);
        }
        bool falloGrande = _revierte(emisorIng, abi.encodeWithSelector(
            IRegistroTitulos.emitirLote.selector, muchosLocs, ConstantesUBO.ING, PROGRAMA, muchosComps));
        Assert.ok(falloGrande, "Pasarse del maximo debe fallar");

        // No se guardó nada
        Assert.equal(titulos.totalTitulos(), 0, "No se debe guardar nada");
    }

    // Suspender, reactivar y rectificar; un revocado ya no se toca
    function cicloDeVidaYRectificacion() public {
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        IRegistroTitulos.Titulo memory t;

        // Suspender
        _ejecutar(emisorIng, abi.encodeCall(
            IRegistroTitulos.suspender, (L1, ConstantesUBO.MOTIVO_EN_INVESTIGACION)));
        t = titulos.obtenerTitulo(L1);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Suspendido), "Queda suspendido");
        Assert.equal(uint256(t.motivo), uint256(ConstantesUBO.MOTIVO_EN_INVESTIGACION), "Guarda el motivo");

        // Reactivar
        _ejecutar(emisorIng, abi.encodeCall(IRegistroTitulos.reactivar, (L1)));
        t = titulos.obtenerTitulo(L1);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Emitido), "Vuelve a Emitido");

        // Reactivar un título que ya está Emitido no se puede
        bool falloReactivar = _revierte(emisorIng, abi.encodeCall(IRegistroTitulos.reactivar, (L1)));
        Assert.ok(falloReactivar, "No se reactiva lo que no esta suspendido");

        // Rectificar: el viejo (L1) se anula y se crea uno nuevo (L2)
        _ejecutar(emisorIng, abi.encodeCall(
            IRegistroTitulos.rectificar, (L1, L2, bytes32(uint256(7)))));

        t = titulos.obtenerTitulo(L1);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Revocado), "El anterior queda Revocado");
        Assert.equal(uint256(t.motivo), uint256(ConstantesUBO.MOTIVO_RECTIFICACION), "Con motivo de rectificacion");
        Assert.equal(bytes32(t.rectificadoComo), bytes32(L2), "Apunta al titulo nuevo");

        t = titulos.obtenerTitulo(L2);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Emitido), "El nuevo queda Emitido");
        Assert.equal(t.compromiso, bytes32(uint256(7)), "Con el compromiso nuevo");
        Assert.equal(t.facultad, ConstantesUBO.ING, "Misma facultad");
        Assert.equal(t.codigoPrograma, PROGRAMA, "Mismo programa");
        Assert.equal(t.emisor, address(emisorIng), "Lo emitio quien rectifico");
        Assert.equal(titulos.totalTitulos(), 2, "Ahora hay 2 titulos");

        // Un revocado es definitivo: no se reactiva, no se suspende y no se revoca de nuevo
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(IRegistroTitulos.reactivar, (L1))),
            "Un revocado no se reactiva"
        );
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(
                IRegistroTitulos.suspender, (L1, ConstantesUBO.MOTIVO_EN_INVESTIGACION))),
            "Un revocado no se suspende"
        );
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(
                IRegistroTitulos.revocar, (L1, ConstantesUBO.MOTIVO_FRAUDE))),
            "Un revocado no se revoca de nuevo"
        );
    }

    // Si rectificar falla al crear el título nuevo, el anterior queda exactamente como estaba
    function rectificacionFallidaNoTocaAnterior() public {
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        _emitir(emisorIng, L2, ConstantesUBO.ING);

        // 1. El nuevo localizador ya existe (L2)
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(IRegistroTitulos.rectificar, (L1, L2, bytes32(uint256(7))))),
            "Rectificar hacia un localizador existente debe fallar"
        );
        // 2. El nuevo localizador tiene formato inválido
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(
                IRegistroTitulos.rectificar, (L1, bytes10("h5j2w7p9d4"), bytes32(uint256(7))))),
            "Rectificar hacia un localizador invalido debe fallar"
        );
        // 3. El compromiso nuevo está vacío
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(IRegistroTitulos.rectificar, (L1, L3, bytes32(0)))),
            "Rectificar con compromiso vacio debe fallar"
        );

        // El anterior no se revocó: la revocación se deshizo junto con la creación fallida
        IRegistroTitulos.Titulo memory t = titulos.obtenerTitulo(L1);
        Assert.equal(uint256(t.estado), uint256(IRegistroTitulos.Estado.Emitido), "El anterior sigue Emitido");
        Assert.equal(uint256(t.motivo), 0, "Sin motivo");
        Assert.equal(bytes32(t.rectificadoComo), bytes32(0), "No apunta a ningun titulo nuevo");
        Assert.equal(t.compromiso, COMPROMISO, "Compromiso intacto");
        Assert.equal(
            uint256(titulos.obtenerTitulo(L3).estado),
            uint256(IRegistroTitulos.Estado.Inexistente),
            "No se creo ningun titulo"
        );
        Assert.equal(titulos.totalTitulos(), 2, "El contador no cambia");
    }

    // Pausa de emergencia: en pausa NO se crean títulos, pero SÍ se pueden anular
    function pausaDeEmergencia() public {
        // Este contrato de prueba ES la administración: puede llamar titulos.pausar()

        // 1. Antes de pausar, todo funciona normal
        _emitir(emisorIng, L1, ConstantesUBO.ING);
        Assert.equal(titulos.totalTitulos(), 1, "Antes de la pausa se emite normal");
        Assert.ok(!titulos.pausado(), "Al inicio no esta en pausa");

        // 2. Alguien que NO es la administración intenta pausar: debe fallar
        Assert.ok(
            _revierte(emisorIng, abi.encodeWithSelector(RegistroTitulos.pausar.selector)),
            "Un emisor no puede pausar"
        );
        Assert.ok(!titulos.pausado(), "Sigue sin estar en pausa");

        // 3. La administración pausa
        titulos.pausar();
        Assert.ok(titulos.pausado(), "Ahora esta en pausa");

        // 4. En pausa NO se pueden crear títulos: emitir, emitirLote y rectificar fallan
        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(
                IRegistroTitulos.emitir, (L2, ConstantesUBO.ING, PROGRAMA, COMPROMISO))),
            "En pausa no se puede emitir"
        );

        bytes10[] memory locs = new bytes10[](2);
        locs[0] = L2;
        locs[1] = L3;
        bytes32[] memory comps = new bytes32[](2);
        comps[0] = bytes32(uint256(1));
        comps[1] = bytes32(uint256(2));
        Assert.ok(
            _revierte(emisorIng, abi.encodeWithSelector(
                IRegistroTitulos.emitirLote.selector, locs, ConstantesUBO.ING, PROGRAMA, comps)),
            "En pausa no se puede emitir un lote"
        );

        Assert.ok(
            _revierte(emisorIng, abi.encodeCall(
                IRegistroTitulos.rectificar, (L1, L2, bytes32(uint256(7))))),
            "En pausa no se puede rectificar (tambien crea un titulo)"
        );

        // No se guardó nada nuevo y el título original no cambió
        Assert.equal(titulos.totalTitulos(), 1, "En pausa no se crea nada");
        Assert.equal(
            uint256(titulos.obtenerTitulo(L1).estado),
            uint256(IRegistroTitulos.Estado.Emitido),
            "Rectificar bloqueado no toca el titulo original"
        );

        // 5. En pausa SÍ se puede anular: suspender, reactivar y revocar funcionan
        _ejecutar(emisorIng, abi.encodeCall(
            IRegistroTitulos.suspender, (L1, ConstantesUBO.MOTIVO_EN_INVESTIGACION)));
        Assert.equal(
            uint256(titulos.obtenerTitulo(L1).estado),
            uint256(IRegistroTitulos.Estado.Suspendido),
            "En pausa se puede suspender"
        );

        _ejecutar(emisorIng, abi.encodeCall(IRegistroTitulos.reactivar, (L1)));
        Assert.equal(
            uint256(titulos.obtenerTitulo(L1).estado),
            uint256(IRegistroTitulos.Estado.Emitido),
            "En pausa se puede reactivar"
        );

        _ejecutar(emisorIng, abi.encodeCall(
            IRegistroTitulos.revocar, (L1, ConstantesUBO.MOTIVO_FRAUDE)));
        Assert.equal(
            uint256(titulos.obtenerTitulo(L1).estado),
            uint256(IRegistroTitulos.Estado.Revocado),
            "En pausa se puede revocar"
        );

        // 6. Un emisor tampoco puede reanudar: sigue en pausa
        Assert.ok(
            _revierte(emisorIng, abi.encodeWithSelector(RegistroTitulos.reanudar.selector)),
            "Un emisor no puede reanudar"
        );
        Assert.ok(titulos.pausado(), "Sigue en pausa");

        // 7. La administración reanuda y vuelve a funcionar la emisión
        titulos.reanudar();
        Assert.ok(!titulos.pausado(), "Ya no esta en pausa");
        _emitir(emisorIng, L2, ConstantesUBO.ING);
        Assert.equal(titulos.totalTitulos(), 2, "Despues de reanudar se emite otra vez");
    }
}