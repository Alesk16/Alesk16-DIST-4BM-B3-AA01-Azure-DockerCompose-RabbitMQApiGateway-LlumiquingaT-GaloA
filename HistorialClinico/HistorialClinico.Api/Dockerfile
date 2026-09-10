FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src

COPY ["HistorialClinico.Api.csproj","./"]

RUN dotnet restore "HistorialClinico.Api.csproj"

COPY . .

RUN dotnet publish "HistorialClinico.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080

ENTRYPOINT ["dotnet", "HistorialClinico.Api.dll"]
