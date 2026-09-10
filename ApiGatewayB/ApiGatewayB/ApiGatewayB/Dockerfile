FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src

COPY ["ApiGatewayB.csproj","./"]

RUN dotnet restore "ApiGatewayB.csproj"

COPY . .

RUN dotnet publish "ApiGatewayB.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080

ENTRYPOINT ["dotnet", "ApiGatewayB.dll"]
