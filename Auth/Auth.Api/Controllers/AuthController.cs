using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Auth.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IConfiguration _configuration;

        public AuthController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpPost("login")]
        public IActionResult Login(LoginRequest loginRequest)
        {
            // NOTA: Los usuarios estan fijos en codigo unicamente para el alcance
            // academico de este proyecto. En un escenario real se validaria contra
            // una tabla de usuarios con contrasenas hasheadas (por ejemplo BCrypt).
            string rol;

            if (loginRequest.Usuario == "admin" && loginRequest.Password == "1234")
            {
                rol = "Administrador";
            }
            else if (loginRequest.Usuario == "usuario" && loginRequest.Password == "1234")
            {
                rol = "Usuario";
            }
            else
            {
                return Unauthorized("Usuario o Contraseña incorrectos");
            }

            var claims = new[]
            {
                new Claim(ClaimTypes.Name, loginRequest.Usuario),
                new Claim(ClaimTypes.Role, rol)
            };

            var key = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]!)
            );

            var credenciales = new SigningCredentials(
                key,
                SecurityAlgorithms.HmacSha256
            );

            var token = new JwtSecurityToken(
                issuer: _configuration["Jwt:Issuer"],
                audience: _configuration["Jwt:Audience"],
                claims: claims,
                expires: DateTime.Now.AddMinutes(
                    Convert.ToDouble(_configuration["Jwt:ExpireMinutes"])
                ),
                signingCredentials: credenciales
            );

            return Ok(new
            {
                token = new JwtSecurityTokenHandler().WriteToken(token),
                usuario = loginRequest.Usuario,
                rol = rol,
            });
        }

        public class LoginRequest
        {
            public string Usuario { get; set; } = string.Empty;
            public string Password { get; set; } = string.Empty;
        }
    }
}
