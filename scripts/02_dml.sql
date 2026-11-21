-- ============================================================================
-- PROJETO: Sistema de Controle de Frota PMBA (Controle de Viaturas)
-- DISCIPLINA: Banco de Dados - Prof. Vagner
-- AUTOR: Caio Barreto
-- SGBD: PostgreSQL 15+
-- SCRIPT: 02_dml.sql (Data Manipulation Language - Carga de Dados, UPDATE e DELETE)
-- ============================================================================

-- ============================================================================
-- 1. CARGA INICIAL DE POLICIAIS (INSERT)
-- ============================================================================
INSERT INTO policiais (nome, matricula, senha, perfil, ativo, patente, email, numero_celular) VALUES
('Caio Barreto',       '301001', '$2b$10$hashExemploAdmin001',    'ADMIN',    TRUE, 'Capitão PM',  'caio.barreto@pmba.ba.gov.br',   '71999881574'),
('Lucas Santana',      '302045', '$2b$10$hashExemploPolicial002', 'POLICIAL', TRUE, 'Soldado PM',  'lucas.santana@pmba.ba.gov.br',  '71991234567'),
('Mariana Oliveira',   '302089', '$2b$10$hashExemploPolicial003', 'POLICIAL', TRUE, 'Cabo PM',     'mariana.oliveira@pmba.ba.gov.br','71992345678'),
('Rafael Costa',       '302112', '$2b$10$hashExemploPolicial004', 'POLICIAL', TRUE, 'Sargento PM', 'rafael.costa@pmba.ba.gov.br',   '71993456789'),
('Thiago Almeida',     '302199', '$2b$10$hashExemploPolicial005', 'POLICIAL', TRUE, 'Soldado PM',  'thiago.almeida@pmba.ba.gov.br', '71994567890');

-- ============================================================================
-- 2. CARGA INICIAL DE VIATURAS (INSERT)
-- ============================================================================
INSERT INTO viaturas (prefixo, placa, chassi, marca, modelo, tipo, ano_fabricacao, km_atual, km_proxima_manutencao, status, ativo, observacao) VALUES
('VTR-01', 'PKZ1A23', '9BG148FK0MC100001', 'Chevrolet', 'S10 4x4',       'CARRO', 2023, 45200, 50000, 'DISPONÍVEL',    TRUE, 'Viatura de radiopatrulhamento setor norte.'),
('VTR-02', 'QTW4B56', '9BWAB45U7NP200002', 'Renault',   'Duster 1.6',    'CARRO', 2022, 69400, 70000, 'DISPONÍVEL',    TRUE, 'Próxima da revisão preventiva de 70.000 km.'),
('VTR-03', 'RJK7C89', '8AD3CRFN0PG300003', 'Toyota',    'Hilux CD',      'CARRO', 2024, 31500, 30000, 'EM MANUTENÇÃO', TRUE, 'Revisão vencida; aguardando troca de pastilhas.'),
('MOT-01', 'SLA2D10', '9C2ND1110PR400004', 'Honda',     'XRE 300',       'MOTO',  2023, 18250, 20000, 'DISPONÍVEL',    TRUE, 'Motopatrulhamento tático.'),
('MOT-02', 'TMB9E34', '9C2ND1110PR400005', 'Yamaha',    'Lander 250',    'MOTO',  2022, 24800, 25000, 'RESERVA',       TRUE, 'Moto reserva da companhia.');

-- ============================================================================
-- 3. CHECKLISTS DE SAÍDA E DEVOLUÇÃO (INSERT)
-- ============================================================================
-- Checklist 1: Saída da VTR-01 (OK)
INSERT INTO checklists_viatura (viatura_id, policial_matricula, km, status, tipo, observacao, data_checklist) VALUES
(1, '302045', 45000, 'OK', 'SAIDA', 'Viatura recebida em perfeitas condições.', '2026-11-18 07:00:00');

-- Checklist 2: Retorno da VTR-01 (PROBLEMA detectado no turno)
INSERT INTO checklists_viatura (viatura_id, policial_matricula, km, status, tipo, observacao, data_checklist) VALUES
(1, '302045', 45200, 'PROBLEMA', 'RETORNO', 'Farol dianteiro direito queimado durante patrulhamento noturno.', '2026-11-18 19:00:00');

-- Checklist 3: Saída da VTR-02 (OK)
INSERT INTO checklists_viatura (viatura_id, policial_matricula, km, status, tipo, observacao, data_checklist) VALUES
(2, '302089', 69150, 'OK', 'SAIDA', 'Tudo regular na assunção do serviço.', '2026-11-19 07:10:00');

-- Checklist 4: Retorno da VTR-02 (OK)
INSERT INTO checklists_viatura (viatura_id, policial_matricula, km, status, tipo, observacao, data_checklist) VALUES
(2, '302089', 69400, 'OK', 'RETORNO', 'Viatura entregue limpa e abastecida.', '2026-11-19 19:05:00');

-- Checklist 5: Saída da MOT-01 (PROBLEMA pré-existente no retrovisor)
INSERT INTO checklists_viatura (viatura_id, policial_matricula, km, status, tipo, observacao, data_checklist) VALUES
(4, '302112', 18100, 'PROBLEMA', 'SAIDA', 'Retrovisor esquerdo com folga na rosca.', '2026-11-20 08:00:00');

-- Checklist 6: Retorno da MOT-01 (PROBLEMA mantido)
INSERT INTO checklists_viatura (viatura_id, policial_matricula, km, status, tipo, observacao, data_checklist) VALUES
(4, '302112', 18250, 'PROBLEMA', 'RETORNO', 'Folga no retrovisor persiste; encaminhar à oficina.', '2026-11-20 16:00:00');

-- ============================================================================
-- 4. ITENS DOS CHECKLISTS (INSERT)
-- ============================================================================
-- Itens do Checklist 1 (VTR-01 - SAIDA)
INSERT INTO checklist_itens (checklist_id, item, status, observacao) VALUES
(1, 'Pneus',                'OK', ''),
(1, 'Freios',               'OK', ''),
(1, 'Óleo/Água',            'OK', ''),
(1, 'Luzes',                'OK', ''),
(1, 'Sirene/Giroflex',      'OK', ''),
(1, 'Vidros/retrovisores',  'OK', ''),
(1, 'Equipamentos',         'OK', ''),
(1, 'Lataria/estado geral', 'OK', '');

-- Itens do Checklist 2 (VTR-01 - RETORNO com problema em Luzes)
INSERT INTO checklist_itens (checklist_id, item, status, observacao) VALUES
(2, 'Pneus',                   'OK',       ''),
(2, 'Freios',                  'OK',       ''),
(2, 'Óleo/Água',               'OK',       ''),
(2, 'Luzes',                   'PROBLEMA', 'Lâmpada do farol dianteiro direito queimada'),
(2, 'Sirene/Giroflex',         'OK',       ''),
(2, 'Vidros/retrovisores',     'OK',       ''),
(2, 'Equipamentos',            'OK',       ''),
(2, 'Lataria/novas avarias',   'OK',       ''),
(2, 'Limpeza interna/cabine',  'OK',       ''),
(2, 'Combustível conferido',   'OK',       '');

-- Itens do Checklist 5 (MOT-01 - SAIDA com problema em Retrovisores)
INSERT INTO checklist_itens (checklist_id, item, status, observacao) VALUES
(5, 'Pneus',                 'OK',       ''),
(5, 'Freios',                'OK',       ''),
(5, 'Óleo/Água',             'OK',       ''),
(5, 'Luzes',                 'OK',       ''),
(5, 'Sirene/Giroflex',       'OK',       ''),
(5, 'Retrovisores',          'PROBLEMA', 'Retrovisor esquerdo frouxo'),
(5, 'Equipamentos',          'OK',       ''),
(5, 'Corrente/estado geral', 'OK',       '');

-- ============================================================================
-- 5. FOTOS DE EVIDÊNCIA DOS CHECKLISTS COM PROBLEMA (INSERT)
-- ============================================================================
INSERT INTO checklist_fotos (checklist_id, foto) VALUES
(2, 'uploads/checklists/vtr01_farol_direito_01.jpg'),
(2, 'uploads/checklists/vtr01_farol_direito_02.jpg'),
(5, 'uploads/checklists/mot01_retrovisor_esq_01.jpg'),
(6, 'uploads/checklists/mot01_retrovisor_devolucao_01.jpg');

-- ============================================================================
-- 6. REGISTROS DE SERVIÇO (INSERT)
-- Obs.: combustivel_inicial = litros abastecidos; combustivel_final = valor em R$
-- ============================================================================
INSERT INTO registros_servico (
    nome_policial, matricula, data_servico, prefixo_viatura, placa_viatura,
    km_inicial, km_final, combustivel_inicial, combustivel_final, ocorrencias, observacoes
) VALUES
('Lucas Santana',    '302045', '2026-11-18', 'VTR-01', 'PKZ1A23', 45000, 45200, 35.50, 212.65,
 '[DEVOLUÇÃO]: Itens com problema: Luzes (Lâmpada do farol dianteiro direito queimada).',
 'Patrulhamento ordinário no setor norte sem alterações graves.'),
('Mariana Oliveira', '302089', '2026-11-19', 'VTR-02', 'QTW4B56', 69150, 69400, 42.00, 251.58,
 '', 'Apoio a blitz educativa e rondas escolares.'),
('Rafael Costa',     '302112', '2026-11-20', 'MOT-01', 'SLA2D10', 18100, 18250, 11.20,  67.09,
 '[SAÍDA]: Itens com problema: Retrovisores (Retrovisor esquerdo frouxo).',
 'Rondas em área comercial; recomendada manutenção do retrovisor.'),
('Lucas Santana',    '302045', '2026-11-20', 'VTR-01', 'PKZ1A23', 45200, 45380,  0.00,   0.00,
 '', 'Turno matutino sem necessidade de abastecimento.');

-- ============================================================================
-- 7. EXEMPLOS DE ATUALIZAÇÃO (UPDATE) E REMOÇÃO CONTROLADA (DELETE)
-- ============================================================================
-- Atualiza o KM atual da VTR-01 após o turno de 20/11
UPDATE viaturas
SET km_atual = 45380
WHERE prefixo = 'VTR-01';

-- Desativação lógica (soft delete) de policial afastado/transferido
UPDATE policiais
SET ativo = FALSE
WHERE matricula = '302199';

-- Exemplo de remoção de foto duplicada em um checklist
DELETE FROM checklist_fotos
WHERE foto = 'uploads/checklists/vtr01_farol_direito_02.jpg';
