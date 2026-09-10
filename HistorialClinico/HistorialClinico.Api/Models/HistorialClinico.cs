using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace HistorialClinico.Api.Models
{
    [Table("HistorialClinico")] //indica a entity framework core el nombre de la tabla en sql server
    public class HistorialClinico
    {
        [Key] // mapea el atributo como clave primaria
        [Column("IdHistorialClinico")]
        public int IdHistorialClinico { get; set; } // indicador unico autoincrementable

        [Column("IdPaciente")]
        public int IdPaciente { get; set; } // referencia logica al microservicio Paciente.Api

        [StringLength(50)]
        [Column("NumHistoria")]
        public string NumHistoria { get; set; } = string.Empty;

        [StringLength(500)]
        [Column("Diagnostico")]
        public string? Diagnostico { get; set; }

        [StringLength(500)]
        [Column("Tratamiento")]
        public string? Tratamiento { get; set; }

        [Column("Fecha")]
        public DateTime Fecha { get; set; }
    }
}
