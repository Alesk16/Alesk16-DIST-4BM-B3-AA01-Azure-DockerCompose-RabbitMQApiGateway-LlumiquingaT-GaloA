namespace Paciente.Api.Controllers
{
    // El login se movió a un servicio independiente: Auth.Api
    // (carpeta Auth/Auth.Api en la raíz del repo).
    //
    // Paciente.Api YA NO emite tokens JWT, pero sigue validándolos
    // (ver AddAuthentication/AddJwtBearer en Program.cs), usando el mismo
    // Jwt:Key / Jwt:Issuer / Jwt:Audience configurado en Auth.Api. Un token
    // emitido por Auth.Api (POST /api/Auth/login) sigue siendo válido aquí.
}
