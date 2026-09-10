using HistorialClinico.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HistorialClinico.Api.Controllers
{
    [Route("api/[controller]")] // define la ruta api/HistorialClinicos
    [ApiController] // habilita API REST
    public class HistorialClinicosController : ControllerBase
    {
        private readonly HistorialClinicoDBContext _dbContext;

        public HistorialClinicosController(HistorialClinicoDBContext dbContext)
        {
            _dbContext = dbContext;
        }

        // Listar todos los historiales
        [Authorize]
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Models.HistorialClinico>>> GetHistoriales()
        {
            var historiales = await _dbContext.HistorialClinico
                .AsNoTracking()
                .ToListAsync();

            return Ok(historiales);
        }

        // Mostrar un historial por su ID
        [Authorize]
        [HttpGet("{id}")]
        public async Task<ActionResult<Models.HistorialClinico>> GetHistorial(int id)
        {
            var historial = await _dbContext.HistorialClinico
                .AsNoTracking()
                .FirstOrDefaultAsync(h => h.IdHistorialClinico == id);

            if (historial == null) return NotFound();

            return Ok(historial);
        }

        // Listar historiales de un paciente especifico
        [Authorize]
        [HttpGet("paciente/{idPaciente}")]
        public async Task<ActionResult<IEnumerable<Models.HistorialClinico>>> GetHistorialesPorPaciente(int idPaciente)
        {
            var historiales = await _dbContext.HistorialClinico
                .AsNoTracking()
                .Where(h => h.IdPaciente == idPaciente)
                .ToListAsync();

            return Ok(historiales);
        }

        // Crear nuevo registro de historial clinico
        [Authorize(Roles = "Administrador")]
        [HttpPost]
        public async Task<ActionResult<Models.HistorialClinico>> CrearHistorial(Models.HistorialClinico historial)
        {
            _dbContext.HistorialClinico.Add(historial);
            await _dbContext.SaveChangesAsync();

            return CreatedAtAction(nameof(GetHistorial),
                new { id = historial.IdHistorialClinico },
                historial);
        }

        // Actualizar registro existente
        [Authorize(Roles = "Administrador")]
        [HttpPut("{id}")]
        public async Task<IActionResult> ActualizarHistorial(int id, Models.HistorialClinico historial)
        {
            if (id != historial.IdHistorialClinico) return BadRequest();

            _dbContext.Entry(historial).State = EntityState.Modified;
            await _dbContext.SaveChangesAsync();

            return NoContent();
        }

        // Eliminar un registro de historial
        [Authorize(Roles = "Administrador")]
        [HttpDelete("{id}")]
        public async Task<IActionResult> EliminarHistorial(int id)
        {
            var historial = await _dbContext.HistorialClinico.FindAsync(id);

            if (historial == null) return NotFound();

            _dbContext.HistorialClinico.Remove(historial);
            await _dbContext.SaveChangesAsync();

            return NoContent();
        }
    }
}
