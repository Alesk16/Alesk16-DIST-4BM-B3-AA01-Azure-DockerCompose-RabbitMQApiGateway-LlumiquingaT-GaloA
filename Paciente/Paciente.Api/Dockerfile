FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src

COPY ["Paciente.Api.csproj","./"]

RUN dotnet restore "Paciente.Api.csproj"

COPY . .

RUN dotnet publish "Paciente.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080

ENTRYPOINT ["dotnet", "Paciente.Api.dll"]
