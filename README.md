# Sello Libertador — Módulo B: Registro de Títulos

Este repositorio contiene únicamente el trabajo del **Módulo B**, desarrollado en Solidity para el proyecto Sello Libertador.

## Objetivo

Registrar y administrar títulos académicos mediante localizadores públicos de 10 caracteres. En la blockchain se almacena un compromiso criptográfico del documento, no los datos personales del titulado.

## Estructura

```text
Sello_Libertador_Modulo_B/
├── contracts/
│   ├── moduloB/
│   │   └── RegistroTitulos.sol
│   ├── interfaces/
│   │   ├── IRegistroTitulos.sol
│   │   └── IRegistroEmisores.sol
│   ├── comun/
│   │   ├── ConstantesUBO.sol
│   │   └── ActorPruebas.sol
│   └── simulacros/
│       └── SimRegistroEmisores.sol
├── tests/
│   └── ModuloB_test.sol
├── scripts/
│   └── escenario_moduloB.js
└── README.md
```

## Funcionalidades principales

- Emisión individual de títulos.
- Emisión de títulos por lotes (máximo 50).
- Validación del formato del localizador: 10 caracteres entre `0-9` y `A-Z`.
- Validación de emisores autorizados por facultad mediante la interfaz del Módulo A.
- Suspensión, reactivación y revocación de títulos.
- Rectificación de títulos.
- Pausa de emergencia administrada por la dirección autorizada.
- Eventos y errores personalizados para registrar operaciones y manejar errores.

## Dependencias y alcance

El contrato principal `RegistroTitulos.sol` utiliza:
- `IRegistroTitulos.sol`: interfaz del Módulo B.
- `IRegistroEmisores.sol`: interfaz de integración con el Módulo A.
- `ConstantesUBO.sol`: constantes y funciones compartidas del proyecto.

Para ejecutar las pruebas y el escenario demostrativo se incluye `SimRegistroEmisores.sol`, que simula el registro de emisores del Módulo A, y `ActorPruebas.sol`, auxiliar para las pruebas.

**Nota:** `SimRegistroEmisores.sol` es un simulacro para desarrollo y pruebas; no reemplaza el contrato real del Módulo A. La integración definitiva debe utilizar un contrato compatible con `IRegistroEmisores`.

## Compilación y pruebas en Remix

1. Abre [Remix IDE](https://remix.ethereum.org/).
2. Carga la carpeta del repositorio o importa sus archivos.
3. Selecciona un compilador Solidity `0.8.20` o compatible con `^0.8.20`.
4. Compila `contracts/moduloB/RegistroTitulos.sol`.
5. Para las pruebas, compila `tests/ModuloB_test.sol` y ejecuta sus pruebas desde el entorno de pruebas de Remix.

El archivo `scripts/escenario_moduloB.js` contiene un escenario de demostración. Para ejecutarlo, compila primero `SimRegistroEmisores.sol` y `RegistroTitulos.sol`, activa la generación de metadatos si el script necesita los artefactos y utiliza Remix VM.

## Autoría

Módulo B — Registro de Títulos  
Proyecto académico Sello Libertador.
