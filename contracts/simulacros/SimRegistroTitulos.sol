// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRegistroTitulos.sol";
import "../comun/ConstantesUBO.sol";

/// @title SimRegistroTitulos — Simulacro del Módulo B
/// @notice Lo usa el Curso C mientras el Curso B desarrolla el real.
/// @dev    SIMPLIFICACIONES (el módulo real NO puede tenerlas):
///         - No consulta el registro de emisores: cualquiera puede emitir y cambiar estados.
///         - No valida el formato del localizador ni el tamaño del lote.
///         - fijarTitulo() permite fabricar cualquier título para las pruebas.
contract SimRegistroTitulos is IRegistroTitulos {
    mapping(bytes10 => Titulo) private _titulos;

    function emitir(bytes10 localizador, bytes32 facultad, bytes32 codigoPrograma, bytes32 compromiso_)
        public
        override
    {
        require(_titulos[localizador].estado == Estado.Inexistente, "Sim: ya existe");
        _titulos[localizador] = Titulo({
            compromiso: compromiso_,
            emisor: msg.sender,
            facultad: facultad,
            codigoPrograma: codigoPrograma,
            fechaEmision: uint64(block.timestamp),
            estado: Estado.Emitido,
            motivo: ConstantesUBO.MOTIVO_NINGUNO,
            rectificadoComo: bytes10(0)
        });
        emit TituloEmitido(localizador, facultad, compromiso_, msg.sender);
    }

    function emitirLote(
        bytes10[] calldata localizadores,
        bytes32 facultad,
        bytes32 codigoPrograma,
        bytes32[] calldata compromisos
    ) external override {
        require(localizadores.length == compromisos.length, "Sim: largos distintos");
        for (uint256 i = 0; i < localizadores.length; i++) {
            emitir(localizadores[i], facultad, codigoPrograma, compromisos[i]);
        }
    }

    function suspender(bytes10 localizador, uint8 motivo) external override {
        _cambiar(localizador, Estado.Suspendido, motivo);
    }

    function reactivar(bytes10 localizador) external override {
        _cambiar(localizador, Estado.Emitido, ConstantesUBO.MOTIVO_NINGUNO);
    }

    function revocar(bytes10 localizador, uint8 motivo) external override {
        _cambiar(localizador, Estado.Revocado, motivo);
    }

    function rectificar(bytes10 anterior, bytes10 nuevo, bytes32 nuevoCompromiso) external override {
        Titulo memory t = _titulos[anterior];
        emitir(nuevo, t.facultad, t.codigoPrograma, nuevoCompromiso);
        _cambiar(anterior, Estado.Revocado, ConstantesUBO.MOTIVO_RECTIFICACION);
        _titulos[anterior].rectificadoComo = nuevo;
        emit TituloRectificado(anterior, nuevo);
    }

    /// @notice SOLO PARA PRUEBAS: fija un título arbitrario.
    function fijarTitulo(bytes10 localizador, Titulo calldata titulo) external {
        _titulos[localizador] = titulo;
    }

    function obtenerTitulo(bytes10 localizador) external view override returns (Titulo memory) {
        return _titulos[localizador];
    }

    function _cambiar(bytes10 localizador, Estado nuevo, uint8 motivo) private {
        _titulos[localizador].estado = nuevo;
        _titulos[localizador].motivo = motivo;
        emit EstadoCambiado(localizador, nuevo, motivo);
    }
}
