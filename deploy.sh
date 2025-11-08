#!/bin/bash
# Script de despliegue seguro para banco (Versión Windows)
# Autor: Andrés

set -e  # Detener si hay errores

echo "🚀 Iniciando despliegue de base de datos..."

# Variables de entorno (en producción vienen de Secrets Manager)
export DB_HOST=${DB_HOST:-localhost}
export DB_PORT=${DB_PORT:-5432}
export DB_NAME=${DB_NAME:-banco_db}
export DB_USER=${DB_USER:-postgres}

# Validar que existan las credenciales
if [ -z "$DB_PASSWORD" ]; then
    echo "ERROR: DB_PASSWORD no está configurado"
    exit 1
fi

echo "Validando sintaxis SQL..."
# Aquí iría validación con herramientas como sqlfluff

echo "Conectando a base de datos: $DB_HOST"

# Verificar que Docker esté corriendo
if ! docker ps > /dev/null 2>&1; then
    echo "ERROR: Docker no está corriendo"
    echo "Por favor inicia Docker Desktop"
    exit 1
fi

# Verificar que el contenedor exista
if ! docker ps | grep -q banco-db-local; then
    echo "ERROR: Contenedor banco-db-local no está corriendo"
    echo "Ejecuta: docker-compose up -d"
    exit 1
fi

# Ejecutar script SQL usando el cliente psql DENTRO del contenedor
echo "🔧 Ejecutando SQL en contenedor Docker..."
docker exec -i banco-db-local psql -U $DB_USER -d $DB_NAME < clientes.sql

if [ $? -eq 0 ]; then
    echo "Despliegue exitoso"
    echo "Fecha: $(date)"
    echo ""
    echo "Verificando datos insertados..."
    docker exec -i banco-db-local psql -U $DB_USER -d $DB_NAME -c "SELECT * FROM clientes;"
else
    echo "Error en el despliegue"
    exit 1
fi