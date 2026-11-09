// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ActorPruebas — Auxiliar para las pruebas unitarias de Remix
/// @notice En las pruebas de Remix, el contrato de prueba siempre llama con su
///         propia dirección. Para simular a varias personas (tres firmantes, dos
///         emisores, un titulado), se despliega un ActorPruebas por persona y se
///         llama «a través» de él.
/// @dev    Ejemplo:
///             ActorPruebas rector = new ActorPruebas();
///             rector.llamar(address(multifirma),
///                 abi.encodeCall(IMultifirmaUBO.confirmar, (0)));
///         Si la llamada interna revierte, llamar() revierte con el mismo error,
///         por lo que puede usarse dentro de try/catch.
contract ActorPruebas {
    function llamar(address destino, bytes calldata datos) external returns (bytes memory resultado) {
        (bool ok, bytes memory ret) = destino.call(datos);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        return ret;
    }

    /// @notice Versión que no revierte: devuelve si la llamada tuvo éxito.
    function intentar(address destino, bytes calldata datos) external returns (bool ok) {
        (ok,) = destino.call(datos);
    }
}
