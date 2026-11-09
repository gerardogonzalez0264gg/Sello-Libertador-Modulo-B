// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IRegistroTitulos — Interfaz del Módulo B (Curso B)
/// @notice Registro de los títulos de la UBO. El titulado NO necesita billetera:
///         cada título se identifica con un LOCALIZADOR público de 10 caracteres
///         (p. ej. "U0ZSA8QPFN") y en la cadena solo se guarda un compromiso
///         criptográfico del documento, nunca datos personales.
/// @dev    NO MODIFICAR sin acuerdo de los tres cursos.
///         Localizador válido: exactamente 10 caracteres en [0-9A-Z] (ASCII),
///         guardados en un bytes10. Ejemplo: bytes10("U0ZSA8QPFN").
///         Los códigos de motivo están en contracts/comun/ConstantesUBO.sol.
interface IRegistroTitulos {
    enum Estado {
        Inexistente, // 0: el localizador nunca se registró
        Emitido,     // 1: vigente
        Suspendido,  // 2: temporalmente no válido
        Revocado     // 3: no válido de forma definitiva
    }

    struct Titulo {
        bytes32 compromiso;     // keccak256(abi.encode(sal, hashDocumento))
        address emisor;         // dirección del funcionario que lo emitió
        bytes32 facultad;       // p. ej. keccak256("ING")
        bytes32 codigoPrograma; // p. ej. keccak256("ING-INFORMATICA"); no personal
        uint64 fechaEmision;    // block.timestamp de la emisión
        Estado estado;
        uint8 motivo;           // 0 si no hay motivo; ver ConstantesUBO
        bytes10 rectificadoComo; // localizador que lo sustituye; vacío si ninguno
    }

    event TituloEmitido(
        bytes10 indexed localizador,
        bytes32 indexed facultad,
        bytes32 compromiso,
        address emisor
    );
    event EstadoCambiado(bytes10 indexed localizador, Estado estadoNuevo, uint8 motivo);
    event TituloRectificado(bytes10 indexed anterior, bytes10 indexed nuevo);

    /// @notice Registra un título. Solo un emisor autorizado AHORA en `facultad`.
    /// @dev Debe revertir si: el localizador no es válido o ya existe,
    ///      o compromiso = bytes32(0).
    function emitir(bytes10 localizador, bytes32 facultad, bytes32 codigoPrograma, bytes32 compromiso)
        external;

    /// @notice Registra varios títulos de una misma facultad y programa en una transacción.
    /// @dev Debe revertir si: los arreglos tienen distinto largo, están vacíos o
    ///      superan ConstantesUBO.MAX_LOTE; o si cualquier título es inválido
    ///      (en ese caso NO se registra ninguno: todo o nada).
    function emitirLote(
        bytes10[] calldata localizadores,
        bytes32 facultad,
        bytes32 codigoPrograma,
        bytes32[] calldata compromisos
    ) external;

    /// @notice Emitido -> Suspendido. Solo emisor autorizado de la MISMA facultad.
    function suspender(bytes10 localizador, uint8 motivo) external;

    /// @notice Suspendido -> Emitido. Solo emisor autorizado de la MISMA facultad.
    function reactivar(bytes10 localizador) external;

    /// @notice Emitido o Suspendido -> Revocado (definitivo). Solo emisor de la MISMA facultad.
    function revocar(bytes10 localizador, uint8 motivo) external;

    /// @notice Corrige un título con error: revoca `anterior` con MOTIVO_RECTIFICACION y
    ///         registra `nuevo` con la misma facultad y programa y `nuevoCompromiso`.
    function rectificar(bytes10 anterior, bytes10 nuevo, bytes32 nuevoCompromiso) external;

    /// @notice Devuelve el título. Si no existe, devuelve uno vacío con estado
    ///         Inexistente (NO revierte).
    function obtenerTitulo(bytes10 localizador) external view returns (Titulo memory);
}
