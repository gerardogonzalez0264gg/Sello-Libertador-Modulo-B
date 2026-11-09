// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IRegistroEmisores — Interfaz del Módulo A (Curso A)
/// @notice Registro de las direcciones autorizadas para emitir títulos en
///         nombre de la UBO, por facultad, con memoria histórica.
/// @dev    NO MODIFICAR sin acuerdo de los tres cursos.
interface IRegistroEmisores {
    /// @notice Se emite cuando la administración autoriza a un emisor en una facultad.
    event EmisorAutorizado(address indexed emisor, bytes32 indexed facultad, uint256 desde);

    /// @notice Se emite cuando la administración retira la autorización.
    event EmisorRevocado(address indexed emisor, bytes32 indexed facultad, uint256 hasta);

    /// @notice Autoriza a `emisor` en `facultad`. Solo la administración (multifirma).
    /// @dev Debe revertir si el emisor ya está autorizado en esa facultad.
    function autorizarEmisor(address emisor, bytes32 facultad) external;

    /// @notice Retira la autorización de `emisor` en `facultad`. Solo la administración.
    /// @dev Debe revertir si el emisor no está autorizado en esa facultad.
    function revocarEmisor(address emisor, bytes32 facultad) external;

    /// @notice ¿Está autorizado AHORA `emisor` en `facultad`?
    function estaAutorizado(address emisor, bytes32 facultad) external view returns (bool);

    /// @notice ¿Estaba autorizado `emisor` en `facultad` en el instante `momento`
    ///         (marca de tiempo Unix, en segundos)?
    /// @dev Un periodo de autorización es el intervalo [desde, hasta):
    ///      incluye `desde` y excluye `hasta`. Un periodo abierto tiene hasta = 0.
    function estabaAutorizado(address emisor, bytes32 facultad, uint256 momento)
        external
        view
        returns (bool);
}
