using Paciente.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Paciente.Api.Data
{
    public class PacienteDBContext : DbContext
    {
        //Constructor: instanciar objetos
        public PacienteDBContext(DbContextOptions<PacienteDBContext> options) : base(options)
        {

        }

        //set: utilizado para mapear la base de datos con el modelo
        public DbSet<Pacientes> Pacientes { get; set; }
    }
}
