#!/bin/bash
# Script de despliegue seguro 
# Autor: Andrés Quispe

set -e  # Detener si hay errores

echo "Iniciando despliegue de base de datos..."

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
export PGPASSWORD=$DB_PASSWORD

# Ejecutar script SQL
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f clientes.sql

if [ $? -eq 0 ]; then
    echo "Despliegue exitoso"
    echo "Fecha: $(date)"
else
    echo "Error en el despliegue"
    exit 1
fi