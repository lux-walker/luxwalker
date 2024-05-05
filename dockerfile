FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-aspnet
WORKDIR /App
COPY ./luxwalker.web ./
RUN dotnet restore
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /App
COPY --from=build-aspnet /App/out .
ENTRYPOINT ["dotnet", "luxwalker.web.dll"]
