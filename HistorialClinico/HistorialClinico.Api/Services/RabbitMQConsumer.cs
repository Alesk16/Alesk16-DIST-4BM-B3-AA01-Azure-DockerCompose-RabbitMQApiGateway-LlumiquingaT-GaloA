using HistorialClinico.Api.Events;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;

namespace HistorialClinico.Api.Services
{
    public class RabbitMQConsumer : BackgroundService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<RabbitMQConsumer> _logger;
        private readonly IServiceScopeFactory _scopeFactory;

        private IConnection? _connection;
        private IChannel? _channel;

        public RabbitMQConsumer(
            IConfiguration configuration,
            ILogger<RabbitMQConsumer> logger,
            IServiceScopeFactory scopeFactory
            )
        {
            _configuration = configuration;
            _logger = logger;
            _scopeFactory = scopeFactory;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            var factory = new ConnectionFactory
            {
                HostName = _configuration["RabbitMQ:HostName"],
                Port = int.Parse(_configuration["RabbitMQ:Port"]!),
                UserName = _configuration["RabbitMQ:UserName"],
                Password = _configuration["RabbitMQ:Password"]
            };

            _connection = await factory.CreateConnectionAsync();
            _channel = await _connection.CreateChannelAsync();

            var queueName = _configuration["RabbitMQ:QueueName"]!;

            await _channel.QueueDeclareAsync(
                queue: queueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null
            );

            var consumer = new AsyncEventingBasicConsumer(_channel);

            consumer.ReceivedAsync += async (sender, ea) =>
            {
                var body = ea.Body.ToArray();
                var mensaje = Encoding.UTF8.GetString(body);

                var evento = JsonSerializer.Deserialize<PacienteCreadoEvento>(mensaje);

                if (evento != null)
                {
                    _logger.LogInformation(
                        "Paciente creado recibido. IdPaciente: {IdPaciente}",
                        evento.IdPaciente
                    );

                    // Al recibir el evento de paciente creado se abre automaticamente
                    // un historial clinico para ese paciente. El historial nace "vacio"
                    // (sin Diagnostico ni Tratamiento): esos campos se llenan despues
                    // con un PUT cuando haya una consulta real.
                    using var scope = _scopeFactory.CreateScope();
                    var dbContext = scope.ServiceProvider
                        .GetRequiredService<Data.HistorialClinicoDBContext>();

                    // Idempotencia: si el mensaje se reentrega (o se publica dos veces)
                    // no se crea un historial duplicado para el mismo paciente.
                    var yaExiste = await dbContext.HistorialClinico
                        .AnyAsync(h => h.IdPaciente == evento.IdPaciente);

                    if (yaExiste)
                    {
                        _logger.LogInformation(
                            "Ya existe un historial para el paciente {IdPaciente}. No se crea otro.",
                            evento.IdPaciente
                        );
                    }
                    else
                    {
                        var historial = new Models.HistorialClinico
                        {
                            IdPaciente = evento.IdPaciente,
                            NumHistoria = $"HC-{evento.IdPaciente:D6}",
                            Diagnostico = null,
                            Tratamiento = null,
                            Fecha = DateTime.UtcNow.Date
                        };

                        try
                        {
                            dbContext.HistorialClinico.Add(historial);
                            await dbContext.SaveChangesAsync();

                            _logger.LogInformation(
                                "Historial creado automaticamente. IdHistorialClinico: {IdHistorialClinico}, IdPaciente: {IdPaciente}",
                                historial.IdHistorialClinico,
                                historial.IdPaciente
                            );
                        }
                        catch (Exception ex)
                        {
                            // Si falla el guardado (BD caida, datos invalidos, etc.) se
                            // registra el error pero igualmente se hace Ack mas abajo:
                            // no queremos que un mensaje envenenado se reintente de forma
                            // infinita y bloquee la cola. Un reproceso manual seria la via.
                            _logger.LogError(
                                ex,
                                "Error al crear el historial para el paciente {IdPaciente}",
                                evento.IdPaciente
                            );
                        }
                    }
                }

                await _channel.BasicAckAsync(
                    deliveryTag: ea.DeliveryTag,
                    multiple: false
                );
            };

            await _channel.BasicConsumeAsync(
                queue: queueName,
                autoAck: false,
                consumer: consumer
            );

            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
    }
}
