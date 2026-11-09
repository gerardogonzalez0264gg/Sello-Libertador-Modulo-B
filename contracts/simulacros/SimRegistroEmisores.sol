// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRegistroEmisores.sol";

/// @title SimRegistroEmisores — Simulacro del Módulo A
/// @notice Lo usan los Cursos B y C mientras el Curso A desarrolla el real.
/// @dev    SIMPLIFICACIONES (el módulo real NO puede tenerlas):
///         - No hay multifirma: cualquiera puede autorizar o revocar.
///         - Solo recuerda el ÚLTIMO periodo de cada (emisor, facultad).
///         - fijarPeriodo() permite fabricar periodos pasados para las pruebas.
contract SimRegistroEmisores is IRegistroEmisores {
    struct Periodo {
        uint256 desde;
        uint256 hasta; // 0 = abierto
        bool existe;
    }

    mapping(address => mapping(bytes32 => Periodo)) private _periodo;

    function autorizarEmisor(address emisor, bytes32 facultad) external override {
        _periodo[emisor][facultad] = Periodo(block.timestamp, 0, true);
        emit EmisorAutorizado(emisor, facultad, block.timestamp);
    }

    function revocarEmisor(address emisor, bytes32 facultad) external override {
        Periodo storage p = _periodo[emisor][facultad];
        require(p.existe && p.hasta == 0, "Sim: no autorizado");
        p.hasta = block.timestamp;
        emit EmisorRevocado(emisor, facultad, block.timestamp);
    }

    /// @notice SOLO PARA PRUEBAS: fija directamente un periodo [desde, hasta).
    function fijarPeriodo(address emisor, bytes32 facultad, uint256 desde, uint256 hasta) external {
        _periodo[emisor][facultad] = Periodo(desde, hasta, true);
    }

    function estaAutorizado(address emisor, bytes32 facultad) external view override returns (bool) {
        Periodo storage p = _periodo[emisor][facultad];
        return p.existe && p.hasta == 0;
    }

    function estabaAutorizado(address emisor, bytes32 facultad, uint256 momento)
        external
        view
        override
        returns (bool)
    {
        Periodo storage p = _periodo[emisor][facultad];
        if (!p.existe || momento < p.desde) return false;
        return p.hasta == 0 || momento < p.hasta;
    }
}
