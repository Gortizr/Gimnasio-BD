USE master;
GO

CREATE DATABASE GimnasioDB;
GO

USE GimnasioDB;
GO


--tabla socio
CREATE TABLE dbo.Socio (
    id_socio INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    apellido NVARCHAR(50) NOT NULL,
    documento NVARCHAR(20) NOT NULL,
    telefono NVARCHAR(20) NOT NULL,
    email NVARCHAR(100) NULL,
    fecha_registro DATE NOT NULL
        CONSTRAINT DF_Socio_FechaRegistro
        DEFAULT (CONVERT(DATE, GETDATE())),
    estado NVARCHAR(10) NOT NULL
        CONSTRAINT DF_Socio_Estado DEFAULT N'activo',

    CONSTRAINT PK_Socio
        PRIMARY KEY (id_socio),

    CONSTRAINT UQ_Socio_Documento
        UNIQUE (documento),

    CONSTRAINT CK_Socio_Nombre
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_Socio_Apellido
        CHECK (LEN(LTRIM(RTRIM(apellido))) > 0),

    CONSTRAINT CK_Socio_Documento
        CHECK (LEN(LTRIM(RTRIM(documento))) > 0),

    CONSTRAINT CK_Socio_Telefono
        CHECK (LEN(LTRIM(RTRIM(telefono))) > 0),

    CONSTRAINT CK_Socio_Estado
        CHECK (estado IN (N'activo', N'inactivo'))
);
GO

--tabla entrenador
CREATE TABLE dbo.Entrenador (
    id_entrenador INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    apellido NVARCHAR(50) NOT NULL,
    telefono NVARCHAR(20) NOT NULL,
    email NVARCHAR(100) NULL,
    especialidad NVARCHAR(100) NOT NULL,
    estado NVARCHAR(10) NOT NULL
        CONSTRAINT DF_Entrenador_Estado DEFAULT N'activo',

    CONSTRAINT PK_Entrenador
        PRIMARY KEY (id_entrenador),

    CONSTRAINT CK_Entrenador_Nombre
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_Entrenador_Apellido
        CHECK (LEN(LTRIM(RTRIM(apellido))) > 0),

    CONSTRAINT CK_Entrenador_Telefono
        CHECK (LEN(LTRIM(RTRIM(telefono))) > 0),

    CONSTRAINT CK_Entrenador_Especialidad
        CHECK (LEN(LTRIM(RTRIM(especialidad))) > 0),

    CONSTRAINT CK_Entrenador_Estado
        CHECK (estado IN (N'activo', N'inactivo'))
);
GO

---tabla clase
CREATE TABLE dbo.Clase (
    id_clase INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    descripcion NVARCHAR(250) NULL,
    estado NVARCHAR(10) NOT NULL
        CONSTRAINT DF_Clase_Estado DEFAULT N'activo',

    CONSTRAINT PK_Clase
        PRIMARY KEY (id_clase),

    CONSTRAINT UQ_Clase_Nombre
        UNIQUE (nombre),

    CONSTRAINT CK_Clase_Nombre
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_Clase_Descripcion
        CHECK (
            descripcion IS NULL
            OR LEN(LTRIM(RTRIM(descripcion))) > 0
        ),

    CONSTRAINT CK_Clase_Estado
        CHECK (estado IN (N'activo', N'inactivo'))
);
GO


--tabla sesion clase
CREATE TABLE dbo.SesionClase (
    id_sesion INT IDENTITY(1,1) NOT NULL,
    id_clase INT NOT NULL,
    id_entrenador INT NOT NULL,
    inicio DATETIME2(0) NOT NULL,
    fin DATETIME2(0) NOT NULL,
    cupo_maximo INT NOT NULL,
    estado NVARCHAR(15) NOT NULL
        CONSTRAINT DF_SesionClase_Estado DEFAULT N'programada',

    CONSTRAINT PK_SesionClase
        PRIMARY KEY (id_sesion),

    CONSTRAINT FK_SesionClase_Clase
        FOREIGN KEY (id_clase)
        REFERENCES dbo.Clase (id_clase),

    CONSTRAINT FK_SesionClase_Entrenador
        FOREIGN KEY (id_entrenador)
        REFERENCES dbo.Entrenador (id_entrenador),

    CONSTRAINT CK_SesionClase_Horario
        CHECK (fin > inicio),

    CONSTRAINT CK_SesionClase_Cupo
        CHECK (cupo_maximo > 0),

    CONSTRAINT CK_SesionClase_Estado
        CHECK (
            estado IN (
                N'programada',
                N'cancelada',
                N'finalizada'
            )
        )
);
GO


--tabla reservas
CREATE TABLE dbo.Reserva (
    id_reserva INT IDENTITY(1,1) NOT NULL,
    id_socio INT NOT NULL,
    id_sesion INT NOT NULL,
    fecha_reserva DATETIME2(0) NOT NULL
        CONSTRAINT DF_Reserva_Fecha
        DEFAULT (SYSDATETIME()),
    estado NVARCHAR(15) NOT NULL
        CONSTRAINT DF_Reserva_Estado
        DEFAULT N'confirmada',

    CONSTRAINT PK_Reserva
        PRIMARY KEY (id_reserva),

    CONSTRAINT FK_Reserva_Socio
        FOREIGN KEY (id_socio)
        REFERENCES dbo.Socio (id_socio),

    CONSTRAINT FK_Reserva_SesionClase
        FOREIGN KEY (id_sesion)
        REFERENCES dbo.SesionClase (id_sesion),

    CONSTRAINT CK_Reserva_Estado
        CHECK (estado IN (N'confirmada', N'cancelada'))
);
GO

CREATE UNIQUE INDEX UX_Reserva_Socio_Sesion_Confirmada
    ON dbo.Reserva (id_socio, id_sesion)
    WHERE estado = N'confirmada';
GO


--tabla plan membresia
CREATE TABLE dbo.PlanMembresia (
    id_plan INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    duracion_dias INT NOT NULL,
    precio_referencia DECIMAL(10,2) NOT NULL,
    estado NVARCHAR(10) NOT NULL
        CONSTRAINT DF_PlanMembresia_Estado
        DEFAULT N'activo',

    CONSTRAINT PK_PlanMembresia
        PRIMARY KEY (id_plan),

    CONSTRAINT UQ_PlanMembresia_Nombre
        UNIQUE (nombre),

    CONSTRAINT CK_PlanMembresia_Nombre
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_PlanMembresia_Duracion
        CHECK (duracion_dias > 0),

    CONSTRAINT CK_PlanMembresia_Precio
        CHECK (precio_referencia > 0),

    CONSTRAINT CK_PlanMembresia_Estado
        CHECK (estado IN (N'activo', N'inactivo'))
);
GO


--tabla membresiasocio
CREATE TABLE dbo.MembresiaSocio (
    id_membresia INT IDENTITY(1,1) NOT NULL,
    id_socio INT NOT NULL,
    id_plan INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    precio_acordado DECIMAL(10,2) NOT NULL,
    estado NVARCHAR(10) NOT NULL
        CONSTRAINT DF_MembresiaSocio_Estado
        DEFAULT N'activa',

    CONSTRAINT PK_MembresiaSocio
        PRIMARY KEY (id_membresia),

    CONSTRAINT FK_MembresiaSocio_Socio
        FOREIGN KEY (id_socio)
        REFERENCES dbo.Socio (id_socio),

    CONSTRAINT FK_MembresiaSocio_PlanMembresia
        FOREIGN KEY (id_plan)
        REFERENCES dbo.PlanMembresia (id_plan),

    CONSTRAINT CK_MembresiaSocio_Fechas
        CHECK (fecha_fin > fecha_inicio),

    CONSTRAINT CK_MembresiaSocio_Precio
        CHECK (precio_acordado > 0),

    CONSTRAINT CK_MembresiaSocio_Estado
        CHECK (estado IN (N'activa', N'cancelada'))
);
GO

--tabla pago
CREATE TABLE dbo.Pago (
    id_pago INT IDENTITY(1,1) NOT NULL,
    id_membresia INT NOT NULL,
    fecha_pago DATETIME2(0) NOT NULL
        CONSTRAINT DF_Pago_Fecha
        DEFAULT (SYSDATETIME()),
    monto DECIMAL(10,2) NOT NULL,
    metodo_pago NVARCHAR(15) NOT NULL,
    referencia NVARCHAR(100) NULL,
    estado NVARCHAR(10) NOT NULL
        CONSTRAINT DF_Pago_Estado
        DEFAULT N'aplicado',

    CONSTRAINT PK_Pago
        PRIMARY KEY (id_pago),

    CONSTRAINT FK_Pago_MembresiaSocio
        FOREIGN KEY (id_membresia)
        REFERENCES dbo.MembresiaSocio (id_membresia),

    CONSTRAINT CK_Pago_Monto
        CHECK (monto > 0),

    CONSTRAINT CK_Pago_Metodo
        CHECK (
            metodo_pago IN (
                N'efectivo',
                N'tarjeta',
                N'transferencia'
            )
        ),

    CONSTRAINT CK_Pago_Referencia
        CHECK (
            referencia IS NULL
            OR LEN(LTRIM(RTRIM(referencia))) > 0
        ),

    CONSTRAINT CK_Pago_Estado
        CHECK (estado IN (N'aplicado', N'anulado'))
);
GO