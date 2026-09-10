#  ************************** MEMORIA DE COMANDOS AZURE - PROYECTO CLINICA (MICROSERVICIOS) ************************** #
#
#  Este archivo es el historial completo de TODO lo que se hizo para desplegar el proyecto a Azure:
#  no solo los comandos finales que funcionaron, sino tambien los errores reales que salieron en el
#  camino y como se resolvieron. Sirve para volver a desplegar desde cero, para recordar donde quedo
#  cada cosa, y como bitacora de aprendizaje (util para sustentar el proyecto).
#
#  *** ESTE ARCHIVO CONTIENE CONTRASEÑAS EN TEXTO PLANO. NUNCA SUBIR A GITHUB (ver .gitignore). ***
#
#  Nota de honestidad: las secciones 1 a 5 (Resource Group, ACR, SQL Server, Container Apps Environment,
#  Paciente.Api, HistorialClinico.Api, RabbitMQ) se reconstruyeron siguiendo el MISMO PATRON que se uso
#  realmente (confirmado por los recursos que existen hoy en Azure y por los errores/fixes reales que
#  se fueron dando en el camino). Las secciones 6 y 7 (Auth.Api y ApiGatewayB) SI son el texto exacto
#  que se ejecuto, verificado en la sesion donde se desplegaron. Si algun comando de las secciones 1-5
#  no coincide 100% con lo que ya tienes desplegado, ajustalo a lo que exista en tu suscripcion
#  (comandos de verificacion "az ... show/list" en la seccion 8).


## Procesos realizados (en orden real)
1.  Instalar y arreglar Azure CLI (winget, arquitectura 32 vs 64 bits).
2.  Preparar Azure: Resource Group, registrar Resource Providers, Azure Container Registry, Container Apps Environment.
3.  Crear Azure SQL Server + bases PacienteDB y HistorialClinicoDB, usuarios y permisos.
4.  Desplegar Paciente.Api (build, push a ACR, Container App, JWT embebido, secreto de conexion SQL).
5.  Arreglar conectividad SQL de Paciente.Api (DNS, variables de entorno, politica de conexion, login).
6.  Desplegar HistorialClinico.Api (mismo patron, sus propios problemas de conexion).
7.  Desplegar RabbitMQ: primero como Container App (fallo por limitacion de red), luego en Azure Container Instances (funciono).
8.  Conectar Paciente.Api (publisher) e HistorialClinico.Api (consumer) a RabbitMQ.
9.  Extraer el login (JWT) de Paciente.Api hacia un microservicio nuevo: Auth.Api.
10. Desplegar ApiGatewayB (YARP) enrutando /api/Auth, /api/Pacientes y /api/HistorialClinicos.
11. Pruebas finales end-to-end con Postman (coleccion en carpeta Postman/).


##### CONSIDERACIONES IMPORTANTES (lecciones aprendidas en este proyecto) #####
- Variables de entorno anidadas en .NET (ej. "ConnectionStrings:PacientesConnection") se pasan a
  Container Apps con DOBLE guion bajo: ConnectionStrings__PacientesConnection (NO uno solo). Este
  fue el bug mas repetido: con un solo guion bajo la app ignora la variable y usa el default de
  appsettings.json (localhost), dando "Cannot assign requested address [::1]:1433".
- Los secretos de Container Apps (az containerapp secret set) requieren REINICIAR la revision para
  que el cambio tome efecto: az containerapp revision restart --name <app> --resource-group <rg> --revision <rev>
- Azure SQL por defecto usa politica de conexion "Redirect" (necesita puertos 11000-11999, no siempre
  accesibles desde Container Apps) -> "Connection Timeout Expired... post-login phase". Se cambio a
  "Proxy" a nivel de servidor (aplica a todas las BD del servidor, no hay que repetirlo por base):
  az sql server conn-policy update --resource-group <rg> --server <server> --connection-type Proxy
- Si la base de datos SQL esta en tier Serverless (GeneralPurpose con auto-pause, ej. 60 min), el
  PRIMER request despues de inactividad puede tardar mas de 30s en despertar la BD y falla con
  "Connection Timeout Expired" (timeout justo en el borde de 30000ms). No es un bug del codigo:
  hay que reintentar, o agregar "Connect Timeout=60;" a la cadena de conexion para tolerarlo.
- PowerShell: las comillas DOBLES interpolan variables ($var). Si una contraseña contiene el caracter
  $ (ej. $VI7iMk{q880u}), usar SIEMPRE comillas SIMPLES al pasarla como argumento; con comillas dobles
  se corrompe (PowerShell intenta interpretar "$VI7iMk" como variable).
- Los comandos largos con continuacion de linea (backtick `) DEBEN pegarse completos (desde la primera
  linea). Pegar solo la mitad de un comando multilinea, o pegar la salida completa de una terminal
  anterior (incluyendo lineas "PS C:\...>"), genera errores confusos de PowerShell/Get-Process.
- Docker Desktop debe estar ABIERTO Y CORRIENDO (icono de la ballena estable, no "starting") antes de
  "docker build"/"push", si no da: "failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine".
- Esta suscripcion (Free/Student) NO permite "az acr build" (error TasksOperationsNotAllowed) -> hay que
  hacer el build LOCAL con Docker Desktop y luego "docker push" a mano a nuestro ACR.
- La extension "containerapp" de Azure CLI fallaba instalando en la version de 32 bits (pip no
  encontraba wheels precompilados de "cryptography", forzaba build desde codigo fuente que pedia
  Rust/maturin) -> se soluciono desinstalando Azure CLI de 32 bits e instalando la version de 64 bits.
- Docker Hub (rabbitmq:3-management) tiene rate-limit anonimo en las IPs compartidas de Azure
  (RegistryErrorResponse al hacer "az container create") -> se mitigo haciendo "docker pull" local,
  "docker tag"/"push" de la imagen a nuestro propio ACR, y usandola desde ahi con credenciales.
- Container Apps en plan Consumption (sin VNET propia) NO enruta bien trafico TCP crudo entre apps
  hermanas (ingress interno se veia "Healthy" pero los sockets nunca conectaban; ingress externo TCP
  directamente lo rechaza con "ContainerAppTcpRequiresVnet") -> por eso RabbitMQ se movio a Azure
  Container Instances (ACI), que expone el puerto TCP directo con IP/FQDN publico sin pedir VNET.
- Cuando un Container App esta en crash-loop, "az containerapp logs show" falla con "Could not find a
  replica for this app" -> hay que consultar los logs por Log Analytics directamente (seccion 8).
- No mostrar contraseñas en pantalla al compartir capturas de este archivo o de la terminal.


#  ****************************** 0. INSTALAR Y ARREGLAR AZURE CLI ****************************** #
#  Problema real: "winget" no reconocido como comando incluso tras reinstalar/reiniciar -> se
#  abandono winget y se instalo Azure CLI directo por MSI. Luego, "az extension add --name
#  containerapp" fallaba (Pip failed with status code 2 / "Cannot import 'maturin'") porque la
#  version de Azure CLI instalada era de 32 bits y no hay wheels precompilados de "cryptography"
#  para esa arquitectura -> se desinstalo y se reinstalo la version de 64 bits.

# Instalacion via MSI de 64 bits (rutas ABSOLUTAS: un proceso elevado con -Verb RunAs arranca en
# otro directorio de trabajo, una ruta relativa como "AzureCLI64.msi" no se encuentra)
Start-Process msiexec.exe -ArgumentList '/I "C:\Users\llumi\OneDrive\Desktop\Practica-azure-eda\AzureCLI64.msi" /quiet /norestart /log "C:\Users\llumi\OneDrive\Desktop\Practica-azure-eda\azcli64_log.txt"' -Wait -Verb RunAs

az --version
az login

az extension add --name containerapp --upgrade


#  ****************************** 1. RESOURCE GROUP + ACR + ENVIRONMENT (una sola vez) ****************************** #
#  [Patron reconstruido - ya existen en Azure con estos nombres exactos, verificados en la seccion 8]
#  Problemas reales en este paso: "az containerapp env create" fallo con ResourceGroupNotFound (el
#  grupo aun no existia / nombre mal escrito); "az acr create" fallo con MissingSubscriptionRegistration
#  para Microsoft.ContainerRegistry -> hubo que registrar los resource providers ANTES de crear nada.

$rg       = "rg-distribuidas-Clinica"
$location = "eastus"

az group create --name $rg --location $location

az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Sql
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ContainerInstance

# Los registros son asincronos, hay que esperar a que queden "Registered" antes de seguir:
az provider show --namespace Microsoft.ContainerRegistry --query registrationState -o tsv
az provider show --namespace Microsoft.ContainerInstance --query registrationState -o tsv

az acr create --resource-group $rg --name acrdistrrabbitmqapigatewayclinica --sku Basic --admin-enabled true

az containerapp env create --name env-distribuidas-Clinica --resource-group $rg --location $location


#  ****************************** 2. AZURE SQL DATABASE ****************************** #
#  [Patron reconstruido - servidor real: sql-distribuidos-admin.database.windows.net]
#  El login/password del ADMINISTRADOR del servidor SQL no quedo registrado en esta memoria
#  (nunca se compartio en el chat). Anotalo aqui manualmente si lo tienes:
#
#   $sqlAdminUser = "<TU_USUARIO_ADMIN_SQL>"
#   $sqlAdminPass = "<TU_PASSWORD_ADMIN_SQL>"
#
# az sql server create --resource-group $rg --name sql-distribuidos-admin --location $location `
#   --admin-user $sqlAdminUser --admin-password $sqlAdminPass
#
# az sql server firewall-rule create --resource-group $rg --server sql-distribuidos-admin `
#   --name AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Politica de conexion Proxy (evita el problema de puertos 11000-11999 de "Redirect"; se aplica a
# nivel de servidor asi que cubre PacienteDB e HistorialClinicoDB con un solo comando)
az sql server conn-policy update --resource-group $rg --server sql-distribuidos-admin --connection-type Proxy

# Bases de datos (tier General Purpose Serverless -> AutoPauseDelay = 60 min de inactividad,
# confirmado real con: az sql db show ... --query "{tier:sku.tier, autoPauseDelay:autoPauseDelay}")
az sql db create --resource-group $rg --server sql-distribuidos-admin --name PacienteDB `
  --edition GeneralPurpose --family Gen5 --capacity 1 --compute-model Serverless --auto-pause-delay 60

az sql db create --resource-group $rg --server sql-distribuidos-admin --name HistorialClinicoDB `
  --edition GeneralPurpose --family Gen5 --capacity 1 --compute-model Serverless --auto-pause-delay 60

# Usuarios de cada base (ejecutados en Azure Portal -> Query Editor, conectado a CADA base especifica,
# NO a master -> el error tipico si te conectas a master es "usuario ya existe" en la base incorrecta).
# La contraseña de usuario_paciente se tuvo que RESETEAR con ALTER USER porque quedo desincronizada
# entre lo guardado en el secreto de Container Apps y lo real en la base (error 18456 Login failed):

# --- Conectado a PacienteDB ---
# CREATE USER usuario_paciente WITH PASSWORD = '$VI7iMk{q880u}';
# ALTER USER usuario_paciente WITH PASSWORD = '$VI7iMk{q880u}';
# ALTER ROLE db_datareader ADD MEMBER usuario_paciente;
# ALTER ROLE db_datawriter ADD MEMBER usuario_paciente;

# --- Conectado a HistorialClinicoDB ---
# CREATE USER usuario_HistorialClinico WITH PASSWORD = 'nRD_667R+tIX';
# ALTER USER usuario_HistorialClinico WITH PASSWORD = 'nRD_667R+tIX';
# ALTER ROLE db_datareader ADD MEMBER usuario_HistorialClinico;
# ALTER ROLE db_datawriter ADD MEMBER usuario_HistorialClinico;


#  ****************************** 3. PACIENTE.API - COMO SE LEVANTO ****************************** #
#  Problemas reales encontrados (en orden):
#   1. SqlException "Cannot assign requested address [::1]:1433": el env var se llamo
#      "ConnectionStrings_PacientesConnection" (UN guion bajo) -> .NET no lo reconocio como
#      ConnectionStrings:PacientesConnection y cayo al default de appsettings.json (localhost).
#      FIX: usar DOBLE guion bajo -> ConnectionStrings__PacientesConnection.
#   2. SqlException "Name or service not known" resolviendo el servidor: el nombre real del server
#      era "sql-distribuidos-admin", no el que se habia escrito antes. FIX: corregir "Data Source"
#      en la cadena de conexion (verificado con "az sql server list").
#   3. Al pasar la password por PowerShell con comillas DOBLES, el caracter $ de la contraseña
#      ($VI7iMk{q880u}) se interpreto como variable y la corrompio. FIX: comillas SIMPLES.
#   4. "Containerapp must be restarted..." tras actualizar el secreto -> FIX: revision restart.
#   5. SqlException "Connection Timeout Expired... post-login phase" (~29s) -> politica de conexion
#      Redirect necesitaba puertos 11000-11999 no disponibles desde Container Apps. FIX: Proxy
#      (seccion 2). Este problema volvio a aparecer mas adelante por auto-pause de SQL serverless.
#   6. SqlException 18456 "Login failed for user 'usuario_paciente'" -> password desincronizada.
#      FIX: ALTER USER ... WITH PASSWORD (seccion 2) para resincronizar con el secreto de Azure.
#   7. "az acr build" no permitido en esta suscripcion (TasksOperationsNotAllowed) -> build local
#      con Docker Desktop + "docker push" manual (no se pudo usar build remoto en la nube).

$acr       = (az acr list --resource-group $rg --query "[0].name" -o tsv)
$acrServer = (az acr show --name $acr --resource-group $rg --query loginServer -o tsv)
$envName   = (az containerapp env list --resource-group $rg --query "[0].name" -o tsv)
$acrUser   = (az acr credential show --name $acr --query username -o tsv)
$acrPass   = (az acr credential show --name $acr --query "passwords[0].value" -o tsv)

cd "C:\Users\llumi\OneDrive\Desktop\Practica-azure-eda\Paciente\Paciente.Api"
docker build -t "$acrServer/paciente-api:v2" .
docker login $acrServer -u $acrUser -p $acrPass
docker push "$acrServer/paciente-api:v2"

# Cadena de conexion como secreto (comillas SIMPLES por el caracter $ en la contraseña)
az containerapp secret set --name paciente-api --resource-group $rg --secrets `
  paciente-sql='Server=tcp:sql-distribuidos-admin.database.windows.net,1433;Database=PacienteDB;User Id=usuario_paciente;Password=$VI7iMk{q880u};Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;'

az containerapp create --name paciente-api --resource-group $rg --environment $envName `
  --image "$acrServer/paciente-api:v2" --target-port 8080 --ingress external `
  --registry-server $acrServer --registry-username $acrUser --registry-password $acrPass `
  --secrets paciente-sql=secretref:paciente-sql `
  --env-vars ASPNETCORE_ENVIRONMENT=Development ConnectionStrings__PacientesConnection=secretref:paciente-sql `
    RabbitMQ__HostName=rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io RabbitMQ__Port=5672 `
    RabbitMQ__UserName=admin RabbitMQ__Password=admin123 RabbitMQ__QueueName=paciente_creado

# Cada vez que se actualiza el secreto despues de creado, hay que reiniciar la revision:
$revPaciente = az containerapp revision list --name paciente-api --resource-group $rg --query "[0].name" -o tsv
az containerapp revision restart --name paciente-api --resource-group $rg --revision $revPaciente

# Verificacion / logs si algo falla (crash-loop -> "logs show" no sirve, usar Log Analytics):
az containerapp identity assign --name paciente-api --resource-group $rg --system-assigned
$logAnalyticsId = az containerapp env show --name $envName --resource-group $rg --query properties.appLogsConfiguration.logAnalyticsConfiguration.customerId -o tsv
az monitor log-analytics query --workspace $logAnalyticsId --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'paciente-api' | order by TimeGenerated desc | take 30 | project TimeGenerated, Log_s" -o table


#  ****************************** 4. HISTORIALCLINICO.API - COMO SE LEVANTO ****************************** #
#  Mismo patron que Paciente.Api. Problemas reales propios de este servicio:
#   1. Error SQL "usuario ya existe" al re-ejecutar el script de creacion de usuario -> normal si
#      ya se habia corrido antes, se ignora o se usa ALTER USER en vez de CREATE USER.
#   2. TaskCanceledException / "Hosting failed to start" en el arranque -> causado por RabbitMQ
#      inalcanzable en ese momento (ver seccion 5, RabbitMQ aun no existia como recurso).
#   3. RabbitMQ.Client.Exceptions.BrokerUnreachableException conectando a 127.0.0.1:5672 -> el
#      RabbitMQ__HostName no estaba seteado (usaba el default "localhost" de appsettings.json).
#      Como RabbitMQConsumer corre en un BackgroundService y HostOptions.BackgroundServiceException
#      Behavior = StopHost (default), esta excepcion TUMBABA TODO el proceso, no solo el consumer.
#      FIX: desplegar RabbitMQ (seccion 5) y setear RabbitMQ__HostName/Port/UserName/Password.
#   4. "Could not find a replica for this app" al pedir logs de un contenedor en crash-loop ->
#      se consulto Log Analytics directamente (mismo query que en la seccion 3).

cd "C:\Users\llumi\OneDrive\Desktop\Practica-azure-eda\HistorialClinico\HistorialClinico.Api"
docker build -t "$acrServer/historial-api:v1" .
docker push "$acrServer/historial-api:v1"

az containerapp secret set --name historial-api --resource-group $rg --secrets `
  historial-sql='Server=tcp:sql-distribuidos-admin.database.windows.net,1433;Database=HistorialClinicoDB;User Id=usuario_HistorialClinico;Password=nRD_667R+tIX;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;'

az containerapp create --name historial-api --resource-group $rg --environment $envName `
  --image "$acrServer/historial-api:v1" --target-port 8080 --ingress external `
  --registry-server $acrServer --registry-username $acrUser --registry-password $acrPass `
  --secrets historial-sql=secretref:historial-sql `
  --env-vars ASPNETCORE_ENVIRONMENT=Development ConnectionStrings__HistorialClinicoConnection=secretref:historial-sql `
    RabbitMQ__HostName=rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io RabbitMQ__Port=5672 `
    RabbitMQ__UserName=admin RabbitMQ__Password=admin123 RabbitMQ__QueueName=paciente_creado

$revHistorial = az containerapp revision list --name historial-api --resource-group $rg --query "[0].name" -o tsv
az containerapp revision restart --name historial-api --resource-group $rg --revision $revHistorial


#  ****************************** 5. RABBITMQ - LA PARTE MAS COMPLICADA ****************************** #
#  Intento 1 (FALLO): RabbitMQ como Container App con ingress interno, transport tcp.
#    az containerapp create --name rabbitmq --resource-group $rg --environment $envName `
#      --image rabbitmq:3-management --target-port 5672 --ingress internal --transport tcp `
#      --min-replicas 1 --max-replicas 1
#    -> La app quedaba "Healthy" y arrancaba bien, PERO Paciente.Api e HistorialClinico.Api nunca
#       lograban conectar al FQDN/IP interno (timeout de socket puro, sin ningun error de Azure).
#    -> Se malinterpreto al inicio como la alarma de memoria de RabbitMQ (memory high-watermark) y
#       se subieron recursos (--cpu 1.0 --memory 2Gi): NO SOLUCIONO NADA.
#    -> Se intento exponer con ingress EXTERNO + transport tcp: Azure lo rechazo directo con el
#       error "ContainerAppTcpRequiresVnet" (ingress TCP externo exige una VNET propia, que este
#       Container Apps Environment no tiene).
#    -> DIAGNOSTICO REAL: en plan Consumption sin VNET, Container Apps no enruta trafico TCP crudo
#       de forma confiable entre apps hermanas (ni con ingress interno ni externo). Limitacion de
#       la plataforma, no un error de configuracion nuestra.
#  Intento 2 (FUNCIONO): mover RabbitMQ a Azure Container Instances (ACI), que expone el puerto
#    directo con IP/FQDN publico sin pedir VNET.
#    -> "az container create" fallo primero con (MissingSubscriptionRegistration) para
#       Microsoft.ContainerInstance -> se registro el provider (seccion 1) y se espero "Registered".
#    -> Luego fallo con (RegistryErrorResponse) al traer "rabbitmq:3-management" desde Docker Hub
#       (index.docker.io) -> rate-limit anonimo en las IPs compartidas de infraestructura de Azure.
#       FIX: mirror manual de la imagen a nuestro propio ACR (con credenciales, sin rate-limit).

# Mirror de la imagen a nuestro ACR
docker pull rabbitmq:3-management
docker tag rabbitmq:3-management "$acrServer/rabbitmq:3-management"
docker login $acrServer -u $acrUser -p $acrPass
docker push "$acrServer/rabbitmq:3-management"

az container create --resource-group $rg --name rabbitmq-clinica-distribuidas-2026 `
  --image "$acrServer/rabbitmq:3-management" `
  --registry-login-server $acrServer --registry-username $acrUser --registry-password $acrPass `
  --ports 5672 15672 --dns-name-label rabbitmq-clinica-distribuidas-2026 `
  --environment-variables RABBITMQ_DEFAULT_USER=admin RABBITMQ_DEFAULT_PASS=admin123 `
  --cpu 1 --memory 2

# FQDN resultante: rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io
# Management UI: http://rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io:15672 (admin/admin123)

# Con RabbitMQ ya arriba en ACI, se actualizaron los dos microservicios para apuntar al nuevo host
# (mismo patron de --set-env-vars usado en la creacion de las secciones 3 y 4):
az containerapp update --name paciente-api  --resource-group $rg --set-env-vars RabbitMQ__HostName=rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io
az containerapp update --name historial-api --resource-group $rg --set-env-vars RabbitMQ__HostName=rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io

# Limpieza opcional: borrar la Container App "rabbitmq" del intento 1, ya no se usa
# az containerapp delete --name rabbitmq --resource-group $rg --yes


#  ****************************** 6. AUTH.API (extraido de Paciente.Api - texto EXACTO usado) ****************************** #
#  Se creo este microservicio nuevo para separar el login/JWT que antes vivia dentro de Paciente.Api.
#  No necesita base de datos (usuarios fijos en codigo). Debe compartir el MISMO Jwt:Key/Issuer/
#  Audience que Paciente.Api e HistorialClinico.Api, porque son ellos quienes validan el token que
#  Auth.Api emite.

$acr       = (az acr list --resource-group $rg --query "[0].name" -o tsv)
$acrServer = (az acr show --name $acr --resource-group $rg --query loginServer -o tsv)
$envName   = (az containerapp env list --resource-group $rg --query "[0].name" -o tsv)
$acrUser   = (az acr credential show --name $acr --query username -o tsv)
$acrPass   = (az acr credential show --name $acr --query "passwords[0].value" -o tsv)

cd "C:\Users\llumi\OneDrive\Desktop\Practica-azure-eda\Auth\Auth.Api"
docker build -t "$acrServer/auth-api:v1" .
docker login $acrServer -u $acrUser -p $acrPass
docker push "$acrServer/auth-api:v1"

az containerapp create --name auth-api --resource-group $rg --environment $envName `
  --image "$acrServer/auth-api:v1" --target-port 8080 --ingress external `
  --registry-server $acrServer --registry-username $acrUser --registry-password $acrPass `
  --env-vars ASPNETCORE_ENVIRONMENT=Development `
    Jwt__Key="ClaveSuperSecretaClinicaJWT2026CambiarEnProduccion" `
    Jwt__Issuer=ClinicaApi Jwt__Audience=ClinicaApiUsers Jwt__ExpireMinutes=60

# FQDN resultante: auth-api.kindmeadow-02f0a420.eastus.azurecontainerapps.io


#  ****************************** 7. APIGATEWAY (YARP - texto EXACTO usado) ****************************** #
#  ApiGatewayB (YARP Reverse Proxy) ya existia como proyecto local; solo faltaba desplegarlo.
#  Se agrego la ruta/cluster de Auth (antes el login vivia en Paciente.Api) apuntando ahora a
#  Auth.Api. Como el gateway no tiene Swagger propio (solo hace MapReverseProxy), se probo con
#  Invoke-RestMethod directo a las rutas /api/Auth, /api/Pacientes y /api/HistorialClinicos.

$fqdnAuth      = az containerapp show --name auth-api      --resource-group $rg --query properties.configuration.ingress.fqdn -o tsv
$fqdnPaciente  = az containerapp show --name paciente-api  --resource-group $rg --query properties.configuration.ingress.fqdn -o tsv
$fqdnHistorial = az containerapp show --name historial-api --resource-group $rg --query properties.configuration.ingress.fqdn -o tsv

cd "C:\Users\llumi\OneDrive\Desktop\Practica-azure-eda\ApiGatewayB\ApiGatewayB\ApiGatewayB"
docker build -t "$acrServer/apigateway:v1" .
docker push "$acrServer/apigateway:v1"

az containerapp create --name apigateway --resource-group $rg --environment $envName `
  --image "$acrServer/apigateway:v1" --target-port 8080 --ingress external `
  --registry-server $acrServer --registry-username $acrUser --registry-password $acrPass `
  --env-vars ASPNETCORE_ENVIRONMENT=Development `
    "ReverseProxy__Clusters__pacientesCluster__Destinations__pacientesDestination__Address=https://$fqdnPaciente/" `
    "ReverseProxy__Clusters__historialCluster__Destinations__historialDestination__Address=https://$fqdnHistorial/" `
    "ReverseProxy__Clusters__authCluster__Destinations__authDestination__Address=https://$fqdnAuth/"

# FQDN resultante: apigateway.kindmeadow-02f0a420.eastus.azurecontainerapps.io

# Prueba end-to-end a traves del gateway:
$loginResp = Invoke-RestMethod -Uri "https://$fqdnGateway/api/Auth/login" -Method Post -ContentType "application/json" -Body '{"usuario":"admin","password":"1234"}'
$token = $loginResp.token
Invoke-RestMethod -Uri "https://$fqdnGateway/api/Pacientes" -Headers @{ Authorization = "Bearer $token" }
Invoke-RestMethod -Uri "https://$fqdnGateway/api/HistorialClinicos" -Headers @{ Authorization = "Bearer $token" }
# Nota real: la primera vez que se probo esto salio 500 (SQL "Connection Timeout Expired") porque
# la base llevaba rato inactiva y el tier Serverless la tenia pausada (auto-pause). Al reintentar
# unos segundos despues (base ya despierta) funciono normal. Ver "Consideraciones importantes".


#  ****************************** 8. RECURSOS, FQDNs Y CREDENCIALES (resumen) ****************************** #

# Resource Group ......... rg-distribuidas-Clinica  (East US)
# ACR ..................... acrdistrrabbitmqapigatewayclinica.azurecr.io  (user/pass: az acr credential show)
# Container Apps Env ...... env-distribuidas-Clinica
# SQL Server .............. sql-distribuidos-admin.database.windows.net  (admin: <no registrado aqui>)
#
# Container Apps:
#   paciente-api  -> https://paciente-api.kindmeadow-02f0a420.eastus.azurecontainerapps.io
#   historial-api -> https://historial-api.kindmeadow-02f0a420.eastus.azurecontainerapps.io
#   auth-api      -> https://auth-api.kindmeadow-02f0a420.eastus.azurecontainerapps.io
#   apigateway    -> https://apigateway.kindmeadow-02f0a420.eastus.azurecontainerapps.io
#
# RabbitMQ (ACI) .......... rabbitmq-clinica-distribuidas-2026.eastus.azurecontainer.io
#   AMQP: 5672 | Management UI: 15672  |  usuario: admin  /  password: admin123
#
# Bases de datos:
#   PacienteDB          -> usuario: usuario_paciente          / password: $VI7iMk{q880u}
#   HistorialClinicoDB  -> usuario: usuario_HistorialClinico  / password: nRD_667R+tIX
#
# JWT (Auth.Api emite, Paciente.Api e HistorialClinico.Api validan):
#   Key:      ClaveSuperSecretaClinicaJWT2026CambiarEnProduccion
#   Issuer:   ClinicaApi
#   Audience: ClinicaApiUsers
#   ExpireMinutes: 60
#
# Usuarios de la app (login POST /api/Auth/login, fijos en codigo):
#   admin   / 1234  -> rol Administrador
#   usuario / 1234  -> rol Usuario
#
# Comandos utiles para volver a consultar cualquiera de estos valores:
az acr credential show --name $acr --query "{user:username, pass:passwords[0].value}" -o table
az containerapp list --resource-group $rg --query "[].{name:name, fqdn:properties.configuration.ingress.fqdn}" -o table
az sql db list --resource-group $rg --server sql-distribuidos-admin --query "[].{name:name, tier:sku.tier, autoPause:autoPauseDelay}" -o table
az container show --resource-group $rg --name rabbitmq-clinica-distribuidas-2026 --query "{fqdn:ipAddress.fqdn, estado:instanceView.state}" -o table


#  ****************************** 9. PRUEBAS (Postman) ****************************** #
#  Coleccion: Postman/Clinica-Microservicios.postman_collection.json
#  Importar en Postman -> Run Collection -> corre login, CRUD de Pacientes/HistorialClinicos,
#  validacion de roles (401/403) y verifica el evento automatico de RabbitMQ.
#  Tambien se puede correr por linea de comandos con Newman:
#    npx newman run "Postman/Clinica-Microservicios.postman_collection.json"
