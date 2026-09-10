
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Paciente.Api.Models
{
    //atributos
    [Table("Pacientes")]
    public class Pacientes
    {
        [Key]
        //[DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Column("IdPaciente")]
        public int IdPaciente { get; set; } //propiedades / formas compactas

        [StringLength(20)]
        [Column("Cedula")]
        public string Cedula { get; set; } = string.Empty;

        [StringLength(100)]
        [Column("Nombre")]
        public string Nombre { get; set; } = string.Empty;

        [StringLength(100)]
        [Column("Apellido")]
        public string Apellido { get; set; } = string.Empty;

        [StringLength(255)]
        [Column("Direccion")]
        public string Direccion { get; set; } = string.Empty;
    }
}
