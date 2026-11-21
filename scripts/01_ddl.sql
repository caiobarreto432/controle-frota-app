-- Controle de Frota PMBA (PostgreSQL 15+)
-- 01_ddl.sql: criação das tabelas, chaves, constraints e índices

DROP TABLE IF EXISTS checklist_fotos CASCADE;
DROP TABLE IF EXISTS checklist_itens CASCADE;
DROP TABLE IF EXISTS checklists_viatura CASCADE;
DROP TABLE IF EXISTS registros_servico CASCADE;
DROP TABLE IF EXISTS policiais CASCADE;
DROP TABLE IF EXISTS viaturas CASCADE;

-- 1. viaturas
CREATE TABLE viaturas (
    id                      SERIAL PRIMARY KEY,
    prefixo                 VARCHAR(10) NOT NULL UNIQUE,
    placa                   VARCHAR(10) NOT NULL UNIQUE,
    chassi                  VARCHAR(50),
    marca                   VARCHAR(50),
    modelo                  VARCHAR(50),
    tipo                    VARCHAR(20) NOT NULL CHECK (tipo IN ('CARRO', 'MOTO')),
    ano_fabricacao          INTEGER CHECK (ano_fabricacao >= 1980 AND ano_fabricacao <= 2100),
    km_atual                NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (km_atual >= 0),
    km_proxima_manutencao   NUMERIC(12, 2) NOT NULL DEFAULT 10000 CHECK (km_proxima_manutencao >= 0),
    status                  VARCHAR(20) NOT NULL DEFAULT 'DISPONÍVEL'
                            CHECK (status IN ('DISPONÍVEL', 'EM MANUTENÇÃO', 'RESERVA', 'BAIXADA')),
    ativo                   BOOLEAN NOT NULL DEFAULT TRUE,
    observacao              TEXT,
    criado_em               TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE viaturas IS 'Cadastro oficial das viaturas da frota operacional (carros e motos).';

-- 2. policiais
CREATE TABLE policiais (
    id                      SERIAL PRIMARY KEY,
    nome                    VARCHAR(200) NOT NULL,
    matricula               VARCHAR(20) NOT NULL UNIQUE,
    senha                   VARCHAR(200) NOT NULL,
    perfil                  VARCHAR(20) NOT NULL DEFAULT 'POLICIAL'
                            CHECK (perfil IN ('ADMIN', 'POLICIAL')),
    ativo                   BOOLEAN NOT NULL DEFAULT TRUE,
    foto                    TEXT,
    email                   VARCHAR(255),
    patente                 VARCHAR(50),
    numero_celular          VARCHAR(30),
    criado_em               TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE policiais IS 'Efetivo policial com acesso autenticado ao sistema de controle de frota.';

-- 3. checklists_viatura
CREATE TABLE checklists_viatura (
    id                      SERIAL PRIMARY KEY,
    viatura_id              INTEGER NOT NULL REFERENCES viaturas(id) ON DELETE CASCADE,
    policial_matricula      VARCHAR(20) NOT NULL REFERENCES policiais(matricula) ON UPDATE CASCADE,
    km                      NUMERIC(12, 2) NOT NULL CHECK (km >= 0),
    status                  VARCHAR(20) NOT NULL CHECK (status IN ('OK', 'PROBLEMA')),
    tipo                    VARCHAR(20) NOT NULL DEFAULT 'SAIDA'
                            CHECK (tipo IN ('SAIDA', 'RETORNO')),
    observacao              TEXT,
    data_checklist          TIMESTAMP NOT NULL DEFAULT NOW(),
    criado_em               TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE checklists_viatura IS 'Registro de vistorias operacionais na assunção (SAIDA) e devolução (RETORNO) da viatura.';

-- 4. checklist_itens
CREATE TABLE checklist_itens (
    id                      SERIAL PRIMARY KEY,
    checklist_id            INTEGER NOT NULL REFERENCES checklists_viatura(id) ON DELETE CASCADE,
    item                    VARCHAR(200) NOT NULL,
    status                  VARCHAR(20) NOT NULL CHECK (status IN ('OK', 'PROBLEMA')),
    observacao              TEXT,
    criado_em               TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE checklist_itens IS 'Itens individuais avaliados em cada checklist (pneus, freios, luzes, sirene, limpeza, etc.).';

-- 5. checklist_fotos
CREATE TABLE checklist_fotos (
    id                      SERIAL PRIMARY KEY,
    checklist_id            INTEGER NOT NULL REFERENCES checklists_viatura(id) ON DELETE CASCADE,
    foto                    TEXT NOT NULL,
    criado_em               TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE checklist_fotos IS 'Caminhos/URLs das fotos comprobatórias anexadas a um checklist com irregularidade.';

-- 6. registros_servico
CREATE TABLE registros_servico (
    id                      SERIAL PRIMARY KEY,
    nome_policial           VARCHAR(200) NOT NULL,
    matricula               VARCHAR(20) NOT NULL REFERENCES policiais(matricula) ON UPDATE CASCADE,
    data_servico            DATE NOT NULL,
    prefixo_viatura         VARCHAR(10) REFERENCES viaturas(prefixo) ON UPDATE CASCADE,
    placa_viatura           VARCHAR(10),
    km_inicial              NUMERIC(12, 2) NOT NULL CHECK (km_inicial >= 0),
    km_final                NUMERIC(12, 2) NOT NULL CHECK (km_final >= km_inicial),
    combustivel_inicial     NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (combustivel_inicial >= 0),
    combustivel_final       NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (combustivel_final >= 0),
    ocorrencias             TEXT,
    observacoes             TEXT,
    criado_em               TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE registros_servico IS 'Registros de turno de uso das viaturas (combustivel_inicial armazena litros e combustivel_final armazena valor em R$).';

-- 7. índices B-Tree
CREATE INDEX idx_registros_matricula          ON registros_servico(matricula);
CREATE INDEX idx_registros_criado_em          ON registros_servico(criado_em DESC);
CREATE INDEX idx_viaturas_prefixo             ON viaturas(prefixo);
CREATE INDEX idx_viaturas_placa               ON viaturas(placa);
CREATE INDEX idx_checklists_viatura_id        ON checklists_viatura(viatura_id);
CREATE INDEX idx_checklists_matricula         ON checklists_viatura(policial_matricula);
CREATE INDEX idx_checklist_fotos_checklist_id ON checklist_fotos(checklist_id);
CREATE INDEX idx_checklist_itens_checklist_id ON checklist_itens(checklist_id);
