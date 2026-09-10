# Guion de video - Proyecto Clínica (Microservicios en Azure)

**Asignatura:** Aplicaciones Distribuidas — Cuarto B Matutina
**Estudiante:** Galo Alejandro Llumiquinga
**Duración estimada:** 8-10 minutos

> Nota de uso: el texto en *cursiva* son indicaciones de qué mostrar en pantalla, no se lee en voz alta. El resto es lo que puedes decir tal cual o con tus palabras.

---

## 1. Introducción (0:00 - 0:45)

*Muestra tu cara o la carátula del proyecto.*

"Hola, mi nombre es Galo Alejandro Llumiquinga, del Cuarto B Matutina de la asignatura Aplicaciones Distribuidas. En este video voy a explicar el proyecto que desarrollé: un sistema de gestión de pacientes e historiales clínicos, construido con una arquitectura de microservicios en .NET y desplegado completamente en Microsoft Azure."

"Voy a mostrar tres cosas: primero la arquitectura general y qué hace cada pieza, segundo los recursos reales desplegados en Azure, y por último una demostración funcionando en vivo."

---

## 2. Arquitectura general (0:45 - 2:30)

*Muestra el diagrama de arquitectura (está en el README.md del repositorio) o dibújalo en una pizarra/PowerPoint mientras hablas.*

"El sistema está compuesto por cuatro microservicios independientes, cada uno en su propio contenedor Docker, más un broker de mensajería:"

"**Auth.Api** es el único responsable de autenticar usuarios y emitir tokens JWT. No tiene base de datos propia; los usuarios están fijos en código para efectos académicos: un usuario `admin` con rol Administrador y un usuario `usuario` con rol Usuario."

"**Paciente.Api** gestiona el CRUD de pacientes, con su propia base de datos SQL Server llamada PacienteDB. Cada vez que se crea un paciente, publica un evento en RabbitMQ."

"**HistorialClinico.Api** gestiona los historiales clínicos, con su propia base de datos HistorialClinicoDB. Escucha en segundo plano la cola de RabbitMQ y, cuando llega un evento de 'paciente creado', genera automáticamente el historial clínico correspondiente — esto demuestra comunicación asíncrona entre microservicios."

"**RabbitMQ** es el broker de mensajería que conecta a Paciente.Api, el publicador, con HistorialClinico.Api, el consumidor."

"Y por último, **ApiGatewayB**, construido con YARP —Yet Another Reverse Proxy—, que es el único punto de entrada público del sistema. Enruta las peticiones de `/api/Auth`, `/api/Pacientes` y `/api/HistorialClinicos` hacia el microservicio correspondiente. El gateway no valida los tokens JWT, simplemente reenvía el header Authorization; son los microservicios de destino los que validan."

"Un detalle importante de diseño: originalmente el login vivía dentro de Paciente.Api. Lo extraje a un microservicio independiente, Auth.Api, para separar responsabilidades — así, la autenticación es un servicio propio que cualquier otro microservicio puede usar, y no depende de que Paciente.Api esté funcionando."

---

## 3. Recursos desplegados en Azure (2:30 - 5:00)

*Comparte pantalla del Azure Portal, en el Resource Group del proyecto.*

"Todo esto está desplegado en Azure, no solo corriendo en mi máquina local. Les muestro los recursos reales:"

"Aquí está mi Resource Group. Dentro tengo:"

- *Señala Azure Container Apps Environment.* "Un **Container Apps Environment**, donde corren los cuatro microservicios como Azure Container Apps: `auth-api`, `paciente-api`, `historial-api` y `apigateway`. Cada uno tiene su propia URL pública con HTTPS."

- *Señala Azure SQL.* "Un **Azure SQL Server** con dos bases de datos: PacienteDB y HistorialClinicoDB, cada una con su propio usuario y permisos de lectura/escritura."

- *Señala Azure Container Registry.* "Un **Azure Container Registry**, donde subo las imágenes Docker de cada microservicio antes de desplegarlas."

- *Señala Azure Container Instances.* "Y RabbitMQ corriendo en **Azure Container Instances**. Tuve que moverlo aquí en lugar de usar Container Apps porque en el plan gratuito, sin una red virtual propia, Container Apps no logra enrutar bien el tráfico TCP crudo de RabbitMQ entre contenedores — fue uno de los problemas más grandes que resolví en este proyecto."

*Opcional: abre uno de los Container Apps y muestra su URL/FQDN, o abre Swagger de uno de los servicios (ej. `https://auth-api.<tu-fqdn>.azurecontainerapps.io/swagger`).*

"Aquí pueden ver, por ejemplo, el Swagger de Auth.Api corriendo directamente desde Azure."

---

## 4. Demostración en vivo (5:00 - 8:00)

*Abre Postman con la colección "Clinica-Microservicios" ya importada.*

"Ahora la parte más importante: la demostración funcionando. Para esto preparé una colección de Postman que prueba todo el flujo de punta a punta, pasando siempre por el Api Gateway."

*Ejecuta la petición "Login Admin" de la carpeta "00 - Auth".*

"Primero, hago login como administrador contra `/api/Auth/login`, a través del gateway. Esto llega hasta Auth.Api, que valida las credenciales y me devuelve un token JWT con el rol Administrador."

*Ejecuta "Crear Paciente (Admin)" de la carpeta "01 - Pacientes".*

"Con ese token, creo un paciente nuevo. Esta petición llega a Paciente.Api, que guarda el paciente en su base de datos y publica un evento en RabbitMQ."

*Cambia a la pestaña del RabbitMQ Management UI (si la tienes abierta) o simplemente continúa con Postman.*

"En este momento, sin que yo haga nada más, HistorialClinico.Api está escuchando esa cola en segundo plano."

*Ejecuta "Historial autogenerado por RabbitMQ" de la carpeta "02 - HistorialClinicos".*

"Y aquí está: sin que yo haya llamado a HistorialClinico.Api directamente, ya existe un historial clínico generado automáticamente para este paciente, con el número de historia `HC-` seguido del id del paciente. Esto confirma la comunicación asíncrona entre microservicios."

*Ejecuta "Crear Paciente sin permisos (403 esperado)" con el token de Usuario.*

"También quiero mostrar la seguridad por roles: si hago login como el usuario normal, sin rol de Administrador, e intento crear un paciente, el sistema me rechaza con un 403 Forbidden. Solo los administradores pueden crear, actualizar o eliminar."

*Opcional: ejecuta la petición sin token para mostrar el 401.*

"Y si intento acceder sin ningún token, obtengo un 401 No autorizado. Todo el sistema está protegido con JWT excepto el login."

*Opcional: corre toda la colección de una vez con "Run Collection" y muestra el resumen final con todos los tests en verde.*

"Para cerrar la demo, puedo correr toda la colección de una sola vez con el Collection Runner de Postman, y ven que las [N] pruebas pasan correctamente: login, CRUD, roles y mensajería asíncrona, todo contra el ambiente real desplegado en Azure."

---

## 5. Retos y aprendizajes (8:00 - 9:15)

*Puedes hablar directo a cámara para esta parte, es más personal/reflexiva.*

"Quiero mencionar brevemente algunos de los retos técnicos reales que enfrenté desplegando esto:"

"Uno: en .NET, las variables de configuración anidadas como `ConnectionStrings:PacientesConnection` se traducen a variables de entorno usando **doble guion bajo**, no uno solo. Este fue el bug que más tiempo me tomó encontrar."

"Dos: Azure SQL por defecto usa una política de conexión llamada 'Redirect' que necesita un rango de puertos que no siempre está disponible desde Container Apps. Tuve que cambiarla a 'Proxy' a nivel de servidor."

"Tres, y el más interesante: RabbitMQ no podía funcionar como Azure Container App normal, porque en el plan gratuito sin red virtual, Container Apps no enruta bien tráfico TCP crudo entre contenedores. Tuve que investigar y moverlo a Azure Container Instances, que sí expone el puerto directamente."

"Y cuatro: mi base de datos usa un tier serverless con auto-pausa por inactividad, así que a veces la primera petición después de un rato sin uso tarda unos segundos extra mientras la base de datos 'despierta' — es normal y no un error del código."

---

## 6. Cierre (9:15 - 9:30)

*Vuelve a mostrar tu cara o la carátula.*

"Con esto concluyo la demostración del proyecto: una arquitectura de microservicios con Auth.Api, Paciente.Api, HistorialClinico.Api y un Api Gateway con YARP, comunicados de forma asíncrona con RabbitMQ, con autenticación y autorización por roles vía JWT, y desplegado completamente en Azure Container Apps, Azure SQL Database, Azure Container Registry y Azure Container Instances. Gracias por su atención."

---

## Checklist antes de grabar

- [ ] Tener Postman abierto con la colección `Clinica-Microservicios.postman_collection.json` ya importada.
- [ ] Verificar que la variable `gatewayUrl` de la colección tiene el FQDN correcto y vigente.
- [ ] Hacer un "Run Collection" de prueba ANTES de grabar, para confirmar que todo pasa en verde (recuerda: el primer request después de inactividad puede fallar por el auto-pause de SQL — corre la colección dos veces si hace falta, para que en la grabación salga todo bien a la primera).
- [ ] Tener el Azure Portal abierto en el Resource Group del proyecto, con las pestañas de Container Apps, SQL, ACR y Container Instances listas para mostrar.
- [ ] Cerrar pestañas/ventanas con información sensible (contraseñas, el archivo "memoria de comandos", claves de Azure) antes de compartir pantalla.
- [ ] Tener el README.md del repositorio abierto por si quieres mostrar el diagrama de arquitectura en vez de dibujarlo.
