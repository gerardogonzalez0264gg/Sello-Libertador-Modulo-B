# Sello Libertador — Módulo B: Registro de Títulos

## Descripción del módulo

Este repositorio contiene el desarrollo del **Módulo B: Registro de Títulos**, perteneciente al proyecto académico Sello Libertador.

El módulo permite registrar y administrar títulos académicos mediante contratos inteligentes desarrollados en Solidity, utilizando la tecnología Blockchain.

Su objetivo es garantizar la integridad, trazabilidad y control de los títulos emitidos por las distintas facultades de la Universidad Bernardo O'Higgins (UBO).

## Objetivo

Implementar un sistema descentralizado para registrar títulos académicos mediante localizadores únicos de 10 caracteres.

En la Blockchain se almacena un compromiso criptográfico del documento, evitando publicar directamente los datos personales del titulado.

## Estructura del proyecto

```text
Sello-Libertador-Modulo-B/
│
├── README.md
│
├── contracts/
│   ├── moduloB/
│   │   └── RegistroTitulos.sol
│   │
│   ├── interfaces/
│   │   ├── IRegistroTitulos.sol
│   │   └── IRegistroEmisores.sol
│   │
│   ├── comun/
│   │   ├── ConstantesUBO.sol
│   │   └── ActorPruebas.sol
│   │
│   └── simulacros/
│       ├── SimRegistroEmisores.sol
│       └── SimRegistroTitulos.sol
│
├── tests/
│   └── ModuloB_test.sol
│
└── scripts/
    └── escenario_moduloB.js
```

## Funcionalidades principales

El contrato `RegistroTitulos.sol` implementa las siguientes funcionalidades:

- **Emisión de títulos:** permite registrar títulos académicos individualmente.
- **Emisión por lotes:** permite registrar varios títulos en una sola operación, con un máximo de 50.
- **Validación de localizadores:** verifica que tengan 10 caracteres alfanuméricos entre 0-9 y A-Z.
- **Control de emisores:** verifica que los emisores estén autorizados en la facultad correspondiente mediante la integración con el Módulo A.
- **Suspensión y reactivación:** permite cambiar el estado de los títulos.
- **Revocación:** permite invalidar definitivamente un título.
- **Rectificación:** permite revocar un título y generar uno nuevo corregido.
- **Pausa de emergencia:** permite a la administración detener temporalmente las operaciones que crean títulos.

## Organización de los contratos

### Contrato principal

- `RegistroTitulos.sol`: contiene la lógica principal del Módulo B para registrar y administrar títulos académicos.

### Interfaces

- `IRegistroTitulos.sol`: define las funciones, estructuras, estados y eventos relacionados con el registro de títulos.
- `IRegistroEmisores.sol`: permite la comunicación con el registro de emisores correspondiente al Módulo A.

### Contratos compartidos

- `ConstantesUBO.sol`: contiene constantes y elementos compartidos del proyecto.
- `ActorPruebas.sol`: contrato auxiliar utilizado para realizar pruebas con diferentes cuentas y emisores.

### Simulacros

- `SimRegistroEmisores.sol`: simula el registro de emisores del Módulo A para realizar pruebas del Módulo B sin depender del contrato definitivo.
- `SimRegistroTitulos.sol`: implementación simplificada del registro de títulos utilizada como apoyo para pruebas e integración con el Curso C. No reemplaza el contrato principal `RegistroTitulos.sol`.

## Pruebas

El archivo `ModuloB_test.sol` contiene las pruebas del módulo utilizando el entorno de pruebas de Remix.

Se contemplan pruebas relacionadas con:

- Emisión de títulos.
- Validación de localizadores.
- Control de permisos y autorizaciones.
- Emisión por lotes.
- Cambios de estado de los títulos.
- Rectificación.
- Pausa de emergencia.

El contrato de pruebas utiliza `SimRegistroEmisores.sol` para simular la autorización de emisores durante la ejecución.

## Script de demostración

El archivo `escenario_moduloB.js` contiene un escenario de demostración para desplegar e interactuar con los contratos desde Remix.

Para ejecutarlo se requiere:

1. Utilizar Remix IDE.
2. Seleccionar el entorno Remix VM.
3. Compilar los contratos necesarios.
4. Activar la generación de metadatos en los ajustes de Remix.
5. Ejecutar el script desde la sección de scripts.

## Tecnologías utilizadas

- Solidity ^0.8.20
- Ethereum Virtual Machine (EVM)
- Remix IDE
- Smart Contracts
- Blockchain

## Integración con otros módulos

El Módulo B forma parte de una arquitectura compuesta por distintos módulos del proyecto Sello Libertador.

Su integración principal se realiza con el Módulo A mediante la interfaz `IRegistroEmisores.sol`, que permite consultar las autorizaciones de los emisores.

También proporciona la interfaz `IRegistroTitulos.sol`, que permite que otros módulos interactúen con el registro de títulos.

## Autoría

**Módulo B — Registro de Títulos**

Proyecto académico Sello Libertador.

Universidad Bernardo O'Higgins (UBO).
