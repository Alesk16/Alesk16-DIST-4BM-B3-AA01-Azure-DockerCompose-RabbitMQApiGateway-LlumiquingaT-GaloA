
using Paciente.Api.Data;
using Paciente.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using System.Text;

namespace Paciente.Api
{
    public class Program
    {
        public static void Main(string[] args)
        {
            var builder = WebApplication.CreateBuilder(args);

            // Add services to the container.

            builder.Services.AddControllers();

            // Registrar el servicio RabbitMQPublisher para inyección de dependencias
            builder.Services.AddScoped<RabbitMQPublisher>();

            // Cadena de conexión: en producción (Azure Container Apps) se inyecta como secreto
            // mediante la variable de entorno "ConnectionStrings__PacientesConnection" (doble guion
            // bajo). Esa variable de entorno SOBRESCRIBE el valor de appsettings*.json.
            var connectionString = builder.Configuration.GetConnectionString("PacientesConnection");

            if (string.IsNullOrWhiteSpace(connectionString))
            {
                throw new InvalidOperationException(
                    "La cadena de conexión 'PacientesConnection' está vacía. " +
                    "En local: defínela en appsettings.Development.json (ConnectionStrings:PacientesConnection). " +
                    "En Azure Container Apps: crea un secreto y expón la variable de entorno " +
                    "'ConnectionStrings__PacientesConnection' (doble guion bajo) que lo referencie.");
            }

            // Log de diagnóstico: muestra a qué servidor apunta la app (sin exponer credenciales).
            try
            {
                var csb = new Microsoft.Data.SqlClient.SqlConnectionStringBuilder(connectionString);
                Console.WriteLine($"[Startup] Paciente.Api -> SQL Server: '{csb.DataSource}', BD: '{csb.InitialCatalog}'");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Startup] Cadena de conexión 'PacientesConnection' con formato inválido: {ex.Message}");
                throw;
            }

            builder.Services.AddDbContext<PacienteDBContext>(options =>
                    options.UseSqlServer(connectionString));

            // JWT
            var jwtKey = builder.Configuration["Jwt:Key"];
            var jwtIssuer = builder.Configuration["Jwt:Issuer"];
            var jwtAudience = builder.Configuration["Jwt:Audience"];

            builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,

                        ValidIssuer = jwtIssuer,
                        ValidAudience = jwtAudience,

                        IssuerSigningKey = new SymmetricSecurityKey(
                            Encoding.UTF8.GetBytes(jwtKey!)
                        )
                    };
                });

            builder.Services.AddAuthorization();

            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(options =>
            {
                options.AddSecurityDefinition("bearer", new OpenApiSecurityScheme
                {
                    Type = SecuritySchemeType.Http,
                    Scheme = "bearer",
                    BearerFormat = "JWT",
                    Description = "Ingrese el token JWT"
                });

                options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
                {
                    [new OpenApiSecuritySchemeReference("bearer", document)] = []
                });
            });

            var app = builder.Build();

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }

            app.UseHttpsRedirection();

            app.UseAuthentication();
            app.UseAuthorization();

            app.MapControllers();

            app.Run();
        }
    }
}
