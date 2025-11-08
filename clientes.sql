-- Tabla de clientes para sistema bancario
-- Autor: Andrés Quispe

CREATE TABLE IF NOT EXISTS clientes (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo', 'suspendido'))
);

-- Índices para mejorar performance
CREATE INDEX IF NOT EXISTS idx_clientes_email ON clientes(email);
CREATE INDEX IF NOT EXISTS idx_clientes_estado ON clientes(estado);

-- Insertar datos de prueba
INSERT INTO clientes (nombre, apellido, email, telefono) VALUES
('Juan', 'Pérez', 'juan.perez@email.com', '987654321'),
('María', 'González', 'maria.gonzalez@email.com', '987654322'),
('Carlos', 'Rodríguez', 'carlos.rodriguez@email.com', '987654323')
('Carlos', 'Rodríguez', 'carlos.rodriguez@email.com', '987654323')
ON CONFLICT (email) DO NOTHING;

-- Verificar datos
SELECT * FROM clientes;