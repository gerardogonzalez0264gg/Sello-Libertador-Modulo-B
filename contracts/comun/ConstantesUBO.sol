// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ConstantesUBO — Valores comunes a los tres módulos de Sello Libertador
/// @notice Uso: import "../comun/ConstantesUBO.sol";  y luego ConstantesUBO.ING
library ConstantesUBO {
    // ---------------------------------------------------------------
    // Facultades de la Universidad Bernardo O'Higgins
    // ---------------------------------------------------------------
    bytes32 internal constant ING = keccak256("ING"); // Ingeniería, Ciencia y Tecnología
    bytes32 internal constant HUM = keccak256("HUM"); // Ciencias Humanas
    bytes32 internal constant SAL = keccak256("SAL"); // Ciencias de la Salud
    bytes32 internal constant MED = keccak256("MED"); // Ciencias Médicas

    // ---------------------------------------------------------------
    // Códigos de motivo de suspensión o revocación (campo Titulo.motivo)
    // ---------------------------------------------------------------
    uint8 internal constant MOTIVO_NINGUNO = 0;
    uint8 internal constant MOTIVO_ERROR_ADMINISTRATIVO = 1;
    uint8 internal constant MOTIVO_FRAUDE = 2;
    uint8 internal constant MOTIVO_RESOLUCION_JUDICIAL = 3;
    uint8 internal constant MOTIVO_RECTIFICACION = 4;
    uint8 internal constant MOTIVO_EN_INVESTIGACION = 5; // típico de una suspensión

    // ---------------------------------------------------------------
    // Límites
    // ---------------------------------------------------------------
    /// @notice Máximo de títulos por llamada a emitirLote (evita DoS por límite de gas).
    uint256 internal constant MAX_LOTE = 50;

    /// @notice ¿Es una facultad reconocida?
    function esFacultadValida(bytes32 facultad) internal pure returns (bool) {
        return facultad == ING || facultad == HUM || facultad == SAL || facultad == MED;
    }

    /// @notice Compromiso criptográfico común a todo el sistema.
    /// @param sal           32 bytes aleatorios, incluidos en el documento cifrado del enlace.
    /// @param hashDocumento keccak256 del documento de la credencial en JSON
    ///                      canonicalizado (RFC 8785).
    function compromiso(bytes32 sal, bytes32 hashDocumento) internal pure returns (bytes32) {
        return keccak256(abi.encode(sal, hashDocumento));
    }

    /// @notice Hoja del árbol de Merkle de una ceremonia (ver IAnclajeLotes).
    function hojaLote(bytes10 localizador, bytes32 compromiso_) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(localizador, compromiso_))));
    }
}
