using Microsoft.EntityFrameworkCore;

namespace HistorialClinico.Api.Data
{
    public class HistorialClinicoDBContext : DbContext
    {
        //Constructor: instanciar objetos
        public HistorialClinicoDBContext(DbContextOptions<HistorialClinicoDBContext> options) : base(options)
        {

        }

        //set: utilizado para mapear la base de datos con el modelo
        public DbSet<Models.HistorialClinico> HistorialClinico { get; set; }
    }
}
