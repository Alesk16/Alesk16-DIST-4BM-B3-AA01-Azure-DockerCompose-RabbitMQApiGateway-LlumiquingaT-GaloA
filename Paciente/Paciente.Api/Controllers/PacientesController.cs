using Paciente.Api.Data;
using Paciente.Api.Models;
using Paciente.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Paciente.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PacientesController : ControllerBase
    {
        private readonly PacienteDBContext _dbContext;
        private readonly RabbitMQPublisher _rabbitMQPublisher;

        public PacientesController(PacienteDBContext dbContext, RabbitMQPublisher rabbitMQPublisher)
        {
            _dbContext = dbContext;
            _rabbitMQPublisher = rabbitMQPublisher;
        }

        //listar
        [Authorize]
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Pacientes>>> GetPacientes()
        {
            var pacientes = await _dbContext.Pacientes
                .AsNoTracking()
                .ToListAsync();

            return Ok(pacientes);
        }

        //mostrar
        [Authorize]
        [HttpGet("{id}")]
        public async Task<ActionResult<Pacientes>> GetPaciente(int id)
        {
            var paciente = await _dbContext.Pacientes
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.IdPaciente == id);

            if (paciente == null) return NotFound();

            return Ok(paciente);
        }

        [Authorize(Roles = "Administrador")]
        [HttpPost]
        public async Task<ActionResult<Pacientes>> CrearPaciente(Pacientes paciente)
        {
            _dbContext.Pacientes.Add(paciente);

            await _dbContext.SaveChangesAsync();

            await _rabbitMQPublisher.PublicarPacienteCreadoAsync(paciente);

            return CreatedAtAction(nameof(GetPaciente),
                new { id = paciente.IdPaciente },
                paciente);
        }

        [Authorize(Roles = "Administrador")]
        [HttpPut("{id}")]
        public async Task<IActionResult> ActualizarPaciente(int id, Pacientes paciente)
        {
            if (id != paciente.IdPaciente) return BadRequest();

            _dbContext.Entry(paciente).State = EntityState.Modified;

            try
            {
                await _dbContext.SaveChangesAsync();
                await _rabbitMQPublisher.PublicarPacienteActualizadoAsync(paciente);
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!PacienteExists(id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        private bool PacienteExists(int id)
        {
            return _dbContext.Pacientes.Any(e => e.IdPaciente == id);
        }

        [Authorize(Roles = "Administrador")]
        [HttpDelete("{id}")]
        public async Task<IActionResult> EliminarPaciente(int id)
        {
            var paciente = await _dbContext.Pacientes.FindAsync(id);

            if (paciente == null) return NotFound();

            _dbContext.Pacientes.Remove(paciente);

            await _dbContext.SaveChangesAsync();

            return NoContent();
        }
    }
}
