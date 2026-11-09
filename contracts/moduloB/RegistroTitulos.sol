// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRegistroTitulos.sol";
import "../interfaces/IRegistroEmisores.sol";
import "../comun/ConstantesUBO.sol";

/// @title RegistroTitulos — Módulo B de Sello Libertador
/// @notice Registro de títulos por localizador, sin billetera del titulado.
/// @dev    Reglas que cumple este contrato:
///         - Solo emisores autorizados AHORA en la facultad (consulta al registro del Módulo A).
///         - Localizador válido: 10 caracteres en [0-9A-Z]; único para siempre.
///         - emitirLote: todo o nada; largos iguales; 1 <= n <= ConstantesUBO.MAX_LOTE;
///           detectar localizadores repetidos DENTRO del mismo lote.
///         - Cambios de estado solo por emisores de la MISMA facultad del título.
///         - Transiciones válidas:
///             Emitido -> Suspendido -> Emitido   (suspender / reactivar)
///             Emitido | Suspendido -> Revocado   (revocar o rectificar; definitivo)
///         - Usar errores personalizados (no cadenas de texto) y eventos de la interfaz.
///         - Pausa de emergencia («circuit breaker»): solo `administracion` (la multifirma
///           del Módulo A) puede pausar y reanudar. REGLA: en pausa se bloquea toda función
///           que CREA un título (emitir, emitirLote y rectificar, que crea el título nuevo).
///           Las que solo INVALIDAN (suspender, revocar) siguen permitidas. El modificador
///           se aplica a la función externa completa: rectificar queda bloqueada entera,
///           aunque por dentro revoque. En pausa, un título erróneo se revoca con revocar()
///           y se rectifica después de reanudar.
contract RegistroTitulos is IRegistroTitulos {
    error NoAutorizado(address cuenta, bytes32 facultad);
    error LocalizadorInvalido(bytes10 localizador);
    error LocalizadorExistente(bytes10 localizador);
    error CompromisoVacio();
    error LoteInvalido(uint256 largoLocalizadores, uint256 largoCompromisos);
    error TituloInexistente(bytes10 localizador);
    error TransicionInvalida(bytes10 localizador, Estado actual);
    error NoEsAdministracion(address cuenta);
    error EnPausa();

    event Pausado(address por);
    event Reanudado(address por);

    IRegistroEmisores public immutable registroEmisores;
    address public immutable administracion;
    bool public pausado;

    mapping(bytes10 => Titulo) private _titulos;

    /// @notice Número total de títulos registrados (útil para estadísticas y pruebas).
    uint256 public totalTitulos;

    constructor(address registroEmisores_, address administracion_) {
        registroEmisores = IRegistroEmisores(registroEmisores_);
        administracion = administracion_;
    }

    modifier soloAdministracion() {
        if (msg.sender != administracion) revert NoEsAdministracion(msg.sender);
        _;
    }

    modifier cuandoNoPausado() {
        // Si el contrato está en pausa, no deja crear títulos
        if (pausado) revert EnPausa();
        _;
    }

    // ---------------------------------------------------------------
    // Pausa de emergencia
    // ---------------------------------------------------------------
    function pausar() external soloAdministracion {
        // Se activa la pausa y se deja el aviso
        pausado = true;
        emit Pausado(msg.sender);
    }

    function reanudar() external soloAdministracion {
        // Se quita la pausa y se deja el aviso
        pausado = false;
        emit Reanudado(msg.sender);
    }

    // ---------------------------------------------------------------
    // Emisión
    // ---------------------------------------------------------------
    function emitir(bytes10 localizador, bytes32 facultad, bytes32 codigoPrograma, bytes32 compromiso)
        external
        override
        cuandoNoPausado
    {
        // Solo pasa si quien llama tiene permiso AHORA en esa facultad
        if (!registroEmisores.estaAutorizado(msg.sender, facultad)) {
            revert NoAutorizado(msg.sender, facultad);
        }
        // Si tiene permiso, se guarda el título
        _registrar(localizador, facultad, codigoPrograma, compromiso);
    }

    function emitirLote(
        bytes10[] calldata localizadores,
        bytes32 facultad,
        bytes32 codigoPrograma,
        bytes32[] calldata compromisos
    ) external override cuandoNoPausado {
        uint256 n = localizadores.length;

        // El lote debe tener al menos 1 título, no pasar del máximo,
        // y tener la misma cantidad de localizadores y de compromisos
        if (n == 0 || n > ConstantesUBO.MAX_LOTE || n != compromisos.length) {
            revert LoteInvalido(n, compromisos.length);
        }

        // Se pregunta por el permiso UNA sola vez para todo el lote (gasta menos)
        if (!registroEmisores.estaAutorizado(msg.sender, facultad)) {
            revert NoAutorizado(msg.sender, facultad);
        }

        // Se guarda uno por uno. Si UNO falla, se deshace todo el lote.
        // Si un localizador viene repetido, el segundo choca con el primero
        // (LocalizadorExistente) y también se deshace todo.
        for (uint256 i = 0; i < n; i++) {
            _registrar(localizadores[i], facultad, codigoPrograma, compromisos[i]);
        }
    }

    // ---------------------------------------------------------------
    // Ciclo de vida
    // ---------------------------------------------------------------
    function suspender(bytes10 localizador, uint8 motivo) external override {
        // Busca el título y revisa que quien llama tenga permiso en SU facultad
        Titulo storage t = _tituloParaCambiar(localizador);

        // Solo se puede suspender un título que está Emitido
        if (t.estado != Estado.Emitido) revert TransicionInvalida(localizador, t.estado);

        t.estado = Estado.Suspendido;
        t.motivo = motivo;
        emit EstadoCambiado(localizador, Estado.Suspendido, motivo);
    }

    function reactivar(bytes10 localizador) external override {
        Titulo storage t = _tituloParaCambiar(localizador);

        // Solo se puede reactivar un título que está Suspendido
        if (t.estado != Estado.Suspendido) revert TransicionInvalida(localizador, t.estado);

        t.estado = Estado.Emitido;
        t.motivo = 0; // ya no hay motivo, vuelve a estar vigente
        emit EstadoCambiado(localizador, Estado.Emitido, 0);
    }

    function revocar(bytes10 localizador, uint8 motivo) external override {
        Titulo storage t = _tituloParaCambiar(localizador);

        // Se puede revocar si está Emitido o Suspendido. Un revocado no se toca más.
        if (t.estado != Estado.Emitido && t.estado != Estado.Suspendido) {
            revert TransicionInvalida(localizador, t.estado);
        }

        t.estado = Estado.Revocado;
        t.motivo = motivo;
        emit EstadoCambiado(localizador, Estado.Revocado, motivo);
    }

    function rectificar(bytes10 anterior, bytes10 nuevo, bytes32 nuevoCompromiso)
        external
        override
        cuandoNoPausado
    {
        // Busca el título anterior y revisa el permiso en su facultad
        Titulo storage t = _tituloParaCambiar(anterior);

        // Solo se puede corregir un título Emitido o Suspendido
        if (t.estado != Estado.Emitido && t.estado != Estado.Suspendido) {
            revert TransicionInvalida(anterior, t.estado);
        }

        // Guardamos los datos que el título nuevo va a heredar
        bytes32 facultad = t.facultad;
        bytes32 programa = t.codigoPrograma;

        // 1. Anulamos el título anterior, dejando anotado quién lo reemplaza
        t.estado = Estado.Revocado;
        t.motivo = ConstantesUBO.MOTIVO_RECTIFICACION;
        t.rectificadoComo = nuevo;
        emit EstadoCambiado(anterior, Estado.Revocado, ConstantesUBO.MOTIVO_RECTIFICACION);

        // 2. Creamos el título nuevo con la misma facultad y programa
        _registrar(nuevo, facultad, programa, nuevoCompromiso);

        // 3. Dejamos el aviso de que uno reemplaza al otro
        emit TituloRectificado(anterior, nuevo);
    }

    function obtenerTitulo(bytes10 localizador) external view override returns (Titulo memory) {
        return _titulos[localizador]; // inexistente => estado Inexistente
    }

    // ---------------------------------------------------------------
    // Funciones internas
    // ---------------------------------------------------------------

    /// @dev Busca un título que se quiere cambiar y revisa dos cosas:
    ///      que exista y que quien llama tenga permiso en la facultad de ESE título.
    function _tituloParaCambiar(bytes10 localizador) internal view returns (Titulo storage t) {
        t = _titulos[localizador];
        if (t.estado == Estado.Inexistente) revert TituloInexistente(localizador);
        if (!registroEmisores.estaAutorizado(msg.sender, t.facultad)) {
            revert NoAutorizado(msg.sender, t.facultad);
        }
    }

    /// @dev Valida y guarda un título; emite TituloEmitido.
    function _registrar(bytes10 localizador, bytes32 facultad, bytes32 codigoPrograma, bytes32 compromiso)
        internal
    {
        // 1. El localizador debe tener 10 caracteres válidos
        if (!_localizadorValido(localizador)) revert LocalizadorInvalido(localizador);

        // 2. No puede existir ya (ni siquiera uno revocado)
        if (_titulos[localizador].estado != Estado.Inexistente) {
            revert LocalizadorExistente(localizador);
        }

        // 3. El compromiso no puede ser todo ceros
        if (compromiso == bytes32(0)) revert CompromisoVacio();

        // Recién ahora guardamos el título
        Titulo storage t = _titulos[localizador];
        t.compromiso = compromiso;
        t.emisor = msg.sender;                    // quien llama, no tx.origin
        t.facultad = facultad;
        t.codigoPrograma = codigoPrograma;
        t.fechaEmision = uint64(block.timestamp); // la hora se pasa a uint64
        t.estado = Estado.Emitido;

        totalTitulos += 1; // sumamos uno al contador (la prueba lo revisa)

        emit TituloEmitido(localizador, facultad, compromiso, msg.sender);
    }

    /// @dev ¿Son los 10 bytes caracteres ASCII '0'-'9' o 'A'-'Z'?
    ///      Un localizador corto se rellena con bytes 0x00, que no son válidos.
    function _localizadorValido(bytes10 localizador) internal pure returns (bool) {
        // Revisamos los 10 caracteres, uno por uno
        for (uint256 i = 0; i < 10; i++) {
            bytes1 b = localizador[i];
            bool esNumero = (b >= "0" && b <= "9"); // de 0 a 9
            bool esLetra = (b >= "A" && b <= "Z");  // de A a Z mayúscula
            // Si un carácter no es número ni letra mayúscula, no sirve
            if (!esNumero && !esLetra) return false;
        }
        return true;
    }
}