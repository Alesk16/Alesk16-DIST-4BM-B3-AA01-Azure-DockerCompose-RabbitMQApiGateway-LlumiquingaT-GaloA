# Clínica - Microservicios

## Descripción

Proyecto desarrollado para la asignatura **Aplicaciones Distribuidas**.

El proyecto implementa una arquitectura de microservicios para la gestión de pacientes e historiales clínicos utilizando .NET, SQL Server, RabbitMQ, Docker y un API Gateway, con autenticación JWT emitida por un microservicio de autenticación independiente. La arquitectura completa está desplegada en **Azure Container Apps** (más Azure SQL Database, Azure Container Registry y Azure Container Instances para RabbitMQ).

El sistema permite registrar pacientes, consultar y registrar historiales clínicos asociados, y comunica ambos servicios de forma asíncrona mediante mensajería con RabbitMQ: al crear un paciente, `HistorialClinico.Api` genera automáticamente su historial clínico.

---

## Arquitectura

```text
                    ┌──────────────┐
   Cliente  ──────► │  ApiGatewayB │  (YARP Reverse Proxy)
                    └──────┬───────┘
             ┌─────────────┼──────────────────┐
             ▼              ▼                  ▼
      ┌────────────┐ ┌─────────────┐  ┌──────────────────────┐
      │  Auth.Api  │ │ Paciente.Api│  │ HistorialClinico.Api  │
      │ (emite JWT)│ │ (valida JWT)│  │    (valida JWT)       │
      └────────────┘ └──────┬──────┘  └───────────┬───────────┘
                             │   publica evento    │  consume evento
                             │  "paciente_creado"   │
                             └────────► RabbitMQ ◄──┘
```

- **Auth.Api**: único responsable de autenticar usuarios y emitir tokens JWT. No tiene base de datos propia.
- **Paciente.Api** / **HistorialClinico.Api**: validan el JWT emitido por Auth.Api (comparten `Key`/`Issuer`/`Audience`), cada uno con su propia base de datos SQL Server.
- **ApiGatewayB**: único punto de entrada público; enruta `/api/Auth`, `/api/Pacientes` y `/api/HistorialClinicos` al microservicio correspondiente. No valida tokens, solo reenvía el header `Authorization`.
- **RabbitMQ**: mensajería asíncrona entre `Paciente.Api` (publisher) e `HistorialClinico.Api` (consumer).

---

## Tecnologías utilizadas

- C#
- ASP.NET Core Web API
- Entity Framework Core
- SQL Server / Azure SQL Database
- RabbitMQ
- Docker / Docker Compose
- API Gateway con YARP
- JWT (JSON Web Tokens)
- Swagger
- Azure Container Apps, Azure Container Registry, Azure Container Instances
- Postman (pruebas automatizadas)
- Visual Studio

---

## Estructura del repositorio

```text
Practica-azure-eda/
│
├── ApiGatewayB/
│   └── Proyecto .NET (YARP Reverse Proxy)
│
├── Auth/
│   └── Auth.Api/
│       └── Proyecto .NET (login y emisión de JWT)
│
├── Paciente/
│   └── Paciente.Api/
│       └── Proyecto .NET
│
├── HistorialClinico/
│   └── HistorialClinico.Api/
│       └── Proyecto .NET
│
├── BaseDatos/
│   ├── PacienteDB.sql
│   └── HistorialClinicoDB.sql
│
├── Postman/
│   └── Clinica-Microservicios.postman_collection.json
│
├── docker-compose.yml
│
├── README.md
│
└── .gitignore
```

---

## Instrucciones de uso (entorno local)

### 1. Crear las bases de datos

Abrir SQL Server Management Studio y conectarse a la instancia local de SQL Server.

Ejecutar los archivos:

```text
BaseDatos/PacienteDB.sql
BaseDatos/HistorialClinicoDB.sql
```

Los scripts crearán las bases de datos `PacienteDB` y `HistorialClinicoDB`, junto con sus respectivos usuarios (`usuario_paciente` y `usuario_HistorialClinico`), permisos de lectura/escritura, tablas y los registros necesarios para realizar las pruebas.

---

### 2. Revisar la configuración de conexión

Las cadenas de conexión hacia SQL Server y RabbitMQ, y la configuración de JWT, están definidas como variables de entorno dentro de `docker-compose.yml`. Los usuarios, contraseñas y nombres de las bases de datos configurados ahí deben coincidir exactamente con los creados en el paso 1.

---

### 3. Abrir Docker Desktop

Asegurarse de que Docker Desktop esté abierto y corriendo antes de continuar.

---

### 4. Ejecutar el proyecto con Docker Compose

Desde la carpeta raíz del proyecto (donde está `docker-compose.yml`), ejecutar en una terminal:

```text
docker compose up --build
```

Esto construye y levanta 5 contenedores:

```text
rabbitmq          -> http://localhost:15672  (usuario: admin / clave: admin123)
auth              -> http://localhost:8086
paciente          -> http://localhost:8083
historialclinico  -> http://localhost:8084
apigateway        -> http://localhost:8085
```

---

### 5. Probar las operaciones de la API

Las peticiones se pueden realizar directo a cada microservicio o a través del Api Gateway.

URL directas:

```text
http://localhost:8086/api/Auth/login
http://localhost:8083/api/Pacientes
http://localhost:8084/api/HistorialClinicos
```

URL a través del Api Gateway:

```text
http://localhost:8085/api/Auth/login
http://localhost:8085/api/Pacientes
http://localhost:8085/api/HistorialClinicos
```

Métodos disponibles en ambos controladores de recursos:

```text
GET     /api/{recurso}
GET     /api/{recurso}/{id}
POST    /api/{recurso}
PUT     /api/{recurso}/{id}
DELETE  /api/{recurso}/{id}
```

Adicional, en `HistorialClinicosController`:

```text
GET /api/HistorialClinicos/paciente/{idPaciente}
```

La forma más rápida de probar todo el flujo es importar la colección de Postman (`Postman/Clinica-Microservicios.postman_collection.json`) y correrla con **Run Collection**: automatiza login, CRUD de pacientes/historiales, validación de roles y la verificación del evento de RabbitMQ.

---

### 6. Comprobar la mensajería con RabbitMQ

Al registrar un paciente (`POST /api/Pacientes`), `Paciente.Api` publica un evento en la cola `paciente_creado`. `HistorialClinico.Api` escucha esa cola en segundo plano y crea automáticamente el historial clínico correspondiente.

Para verificarlo, abrir `http://localhost:15672` e ingresar a la pestaña **Queues** → **paciente_creado**.

---

## Autenticación

Los endpoints de `Paciente.Api` e `HistorialClinico.Api` están protegidos con **JWT (JSON Web Tokens)**. Sin un token válido las peticiones responden `401 Unauthorized`. El login y la emisión de tokens viven en un microservicio independiente: **Auth.Api**.

### Usuarios disponibles

Los usuarios están fijos en código (simplificado para el alcance académico; en un escenario real se validarían contra una tabla de usuarios con contraseñas hasheadas):

```text
usuario: admin     clave: 1234   ->  rol Administrador
usuario: usuario   clave: 1234   ->  rol Usuario
```

### Obtener un token

`POST /api/Auth/login` (vive en `Auth.Api`, alcanzable directo o a través del gateway):

```text
Directo:      http://localhost:8086/api/Auth/login
Vía gateway:  http://localhost:8085/api/Auth/login
```

Body:

```json
{ "usuario": "admin", "password": "1234" }
```

Respuesta:

```json
{ "token": "eyJhbGci...", "usuario": "admin", "rol": "Administrador" }
```

### Usar el token

En cada petición siguiente agregar el header:

```text
Authorization: Bearer {token}
```

En Swagger (`http://localhost:8086/swagger`, `http://localhost:8083/swagger` y `http://localhost:8084/swagger`) usar el botón **Authorize** y pegar el token.

El mismo token sirve para los tres microservicios: `Auth.Api`, `Paciente.Api` e `HistorialClinico.Api` comparten `Key`, `Issuer` y `Audience` (definidos en `docker-compose.yml`), por lo que un token emitido por `Auth.Api` es válido tanto en `Paciente.Api` como en `HistorialClinico.Api`.

El `ApiGatewayB` no valida el token: YARP reenvía el header `Authorization` tal cual hacia los microservicios, que son quienes lo validan.

### Autorización por rol

| Operación | Rol requerido |
|-----------|---------------|
| `POST /api/Auth/login` | Público (sin token) |
| `GET /api/Pacientes`, `GET /api/Pacientes/{id}` | Cualquier usuario autenticado (`Administrador` o `Usuario`) |
| `GET /api/HistorialClinicos`, `GET /api/HistorialClinicos/{id}`, `GET /api/HistorialClinicos/paciente/{idPaciente}` | Cualquier usuario autenticado |
| `POST`, `PUT`, `DELETE` (pacientes e historiales) | Solo rol `Administrador` |

Con un token de `usuario` (rol `Usuario`), las operaciones de escritura responden `403 Forbidden`.

---

## Despliegue en Azure

La arquitectura completa está desplegada en **Azure Container Apps** (Auth.Api, Paciente.Api, HistorialClinico.Api y ApiGatewayB), con **Azure SQL Database** para las bases de datos, **Azure Container Registry** para las imágenes y **Azure Container Instances** para RabbitMQ.

Punto de entrada público (Api Gateway):

```text
https://apigateway.kindmeadow-02f0a420.eastus.azurecontainerapps.io
```

Ejemplo de login vía el gateway desplegado:

```text
POST https://apigateway.kindmeadow-02f0a420.eastus.azurecontainerapps.io/api/Auth/login
Body: { "usuario": "admin", "password": "1234" }
```

> Nota: la base de datos usa un tier *serverless* con auto-pause por inactividad; el primer request tras un rato sin uso puede tardar unos segundos en responder mientras la base "despierta".

---

## Orden de ejecución (entorno local)

```text
1. Iniciar SQL Server
        ↓
2. Ejecutar BaseDatos/PacienteDB.sql
        ↓
3. Ejecutar BaseDatos/HistorialClinicoDB.sql
        ↓
4. Revisar docker-compose.yml
        ↓
5. Abrir Docker Desktop
        ↓
6. Ejecutar: docker compose up --build
        ↓
7. Probar los endpoints (directo, vía Api Gateway, o con la colección de Postman)
        ↓
8. Verificar la cola paciente_creado en RabbitMQ Management
```

---

## Autor

**Estudiante:** Galo Alejandro Llumiquinga
**Asignatura:** Aplicaciones Distribuidas
**Paralelo:** Cuarto B Matutina
