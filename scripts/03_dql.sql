-- ============================================================================
-- PROJETO: Sistema de Controle de Frota PMBA (Controle de Viaturas)
-- DISCIPLINA: Banco de Dados - Prof. Vagner
-- AUTOR: Caio Barreto
-- SGBD: PostgreSQL 15+
-- SCRIPT: 03_dql.sql (Data Query Language - Consultas Analíticas e Operacionais)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Q01. Painel de Manutenção Preventiva das Viaturas Ativas
-- Calcula o KM restante e classifica cada viatura como VENCIDA, PROXIMA ou NORMAL.
-- ----------------------------------------------------------------------------
SELECT
    prefixo,
    placa,
    tipo,
    modelo,
    km_atual,
    km_proxima_manutencao,
    (km_proxima_manutencao - km_atual) AS km_restante,
    CASE
        WHEN (km_proxima_manutencao - km_atual) <= 0    THEN 'VENCIDA'
        WHEN (km_proxima_manutencao - km_atual) <= 1000 THEN 'PROXIMA'
        ELSE 'NORMAL'
    END AS situacao_manutencao,
    status
FROM viaturas
WHERE ativo = TRUE
ORDER BY km_restante ASC;

-- ----------------------------------------------------------------------------
-- Q02. Consolidado de Quilometragem e Abastecimento por Viatura (GROUP BY + SUM)
-- ----------------------------------------------------------------------------
SELECT
    v.prefixo,
    v.placa,
    v.modelo,
    COUNT(r.id)                              AS total_turnos,
    COALESCE(SUM(r.km_final - r.km_inicial), 0) AS total_km_rodado,
    COALESCE(SUM(r.combustivel_inicial), 0)  AS total_litros,
    COALESCE(SUM(r.combustivel_final), 0)    AS total_gasto_reais
FROM viaturas v
LEFT JOIN registros_servico r ON r.prefixo_viatura = v.prefixo
GROUP BY v.id, v.prefixo, v.placa, v.modelo
ORDER BY total_km_rodado DESC;

-- ----------------------------------------------------------------------------
-- Q03. Ranking de Policiais por Quilometragem Percorrida e Turnos Realizados
-- ----------------------------------------------------------------------------
SELECT
    p.patente,
    p.nome,
    p.matricula,
    COUNT(r.id)                           AS qtd_servicos,
    SUM(r.km_final - r.km_inicial)        AS km_total_rodado,
    ROUND(AVG(r.km_final - r.km_inicial), 2) AS media_km_por_turno
FROM policiais p
INNER JOIN registros_servico r ON r.matricula = p.matricula
GROUP BY p.patente, p.nome, p.matricula
ORDER BY km_total_rodado DESC;

-- ----------------------------------------------------------------------------
-- Q04. Histórico Completo de Checklists (SAÍDA vs DEVOLUÇÃO) com JOIN Triplo
-- ----------------------------------------------------------------------------
SELECT
    c.id              AS checklist_id,
    c.data_checklist,
    c.tipo            AS momento_vistoria,
    v.prefixo,
    v.placa,
    p.patente || ' ' || p.nome AS policial,
    c.km,
    c.status          AS status_geral,
    c.observacao
FROM checklists_viatura c
INNER JOIN viaturas v ON v.id = c.viatura_id
INNER JOIN policiais p ON p.matricula = c.policial_matricula
ORDER BY c.data_checklist DESC;

-- ----------------------------------------------------------------------------
-- Q05. Auditoria de Avarias: Itens com PROBLEMA e Quantidade de Fotos Anexadas
-- ----------------------------------------------------------------------------
SELECT
    v.prefixo,
    c.tipo            AS momento_vistoria,
    c.data_checklist,
    p.nome            AS policial_responsavel,
    ci.item           AS item_com_problema,
    ci.observacao     AS detalhe_item,
    COUNT(cf.id)      AS qtd_fotos_evidencia
FROM checklist_itens ci
INNER JOIN checklists_viatura c ON c.id = ci.checklist_id
INNER JOIN viaturas v           ON v.id = c.viatura_id
INNER JOIN policiais p          ON p.matricula = c.policial_matricula
LEFT JOIN checklist_fotos cf    ON cf.checklist_id = c.id
WHERE ci.status = 'PROBLEMA'
GROUP BY v.prefixo, c.tipo, c.data_checklist, p.nome, ci.item, ci.observacao
ORDER BY c.data_checklist DESC;

-- ----------------------------------------------------------------------------
-- Q06. Detecção de Novas Avarias no Plantão (Saída OK → Devolução com PROBLEMA)
-- ----------------------------------------------------------------------------
SELECT
    v.prefixo,
    p.nome                  AS policial,
    c_saida.data_checklist  AS horario_saida,
    c_ret.data_checklist    AS horario_devolucao,
    c_saida.km              AS km_saida,
    c_ret.km                AS km_devolucao,
    c_ret.observacao        AS problema_na_devolucao
FROM checklists_viatura c_saida
INNER JOIN checklists_viatura c_ret
    ON c_ret.viatura_id = c_saida.viatura_id
   AND c_ret.policial_matricula = c_saida.policial_matricula
   AND DATE(c_ret.data_checklist) = DATE(c_saida.data_checklist)
INNER JOIN viaturas v  ON v.id = c_saida.viatura_id
INNER JOIN policiais p ON p.matricula = c_saida.policial_matricula
WHERE c_saida.tipo = 'SAIDA'
  AND c_saida.status = 'OK'
  AND c_ret.tipo = 'RETORNO'
  AND c_ret.status = 'PROBLEMA';

-- ----------------------------------------------------------------------------
-- Q07. Viaturas com Custo de Abastecimento Acima de R$ 100,00 (HAVING)
-- ----------------------------------------------------------------------------
SELECT
    prefixo_viatura,
    SUM(km_final - km_inicial)                                 AS km_rodados,
    SUM(combustivel_inicial)                                   AS litros_totais,
    SUM(combustivel_final)                                     AS gasto_total_reais,
    ROUND(SUM(combustivel_final) / NULLIF(SUM(km_final - km_inicial), 0), 2) AS custo_por_km
FROM registros_servico
GROUP BY prefixo_viatura
HAVING SUM(combustivel_final) > 100
ORDER BY gasto_total_reais DESC;

-- ----------------------------------------------------------------------------
-- Q08. Consulta Estruturada com JSON_AGG (Padrão da API para o App Flutter)
-- Retorna os checklists de uma viatura já agregando itens e fotos em JSON.
-- ----------------------------------------------------------------------------
SELECT
    c.id,
    c.viatura_id,
    c.policial_matricula,
    c.km,
    c.status,
    c.tipo,
    c.observacao,
    c.data_checklist,
    COALESCE(
        (SELECT json_agg(json_build_object(
            'item', ci.item,
            'status', ci.status,
            'observacao', ci.observacao
        ) ORDER BY ci.id)
         FROM checklist_itens ci
         WHERE ci.checklist_id = c.id),
        '[]'::json
    ) AS itens,
    COALESCE(
        (SELECT json_agg(json_build_object(
            'id', cf.id,
            'foto', cf.foto
        ) ORDER BY cf.id)
         FROM checklist_fotos cf
         WHERE cf.checklist_id = c.id),
        '[]'::json
    ) AS fotos
FROM checklists_viatura c
WHERE c.viatura_id = 1
ORDER BY c.data_checklist DESC;

-- ----------------------------------------------------------------------------
-- Q09. Distribuição do Efetivo Ativo por Perfil de Acesso (ADMIN vs POLICIAL)
-- ----------------------------------------------------------------------------
SELECT
    perfil,
    COUNT(*) AS total_ativos
FROM policiais
WHERE ativo = TRUE
GROUP BY perfil;

-- ----------------------------------------------------------------------------
-- Q10. Relatório de Turnos com Ocorrências / Avarias Registradas
-- ----------------------------------------------------------------------------
SELECT
    data_servico,
    prefixo_viatura,
    placa_viatura,
    nome_policial,
    (km_final - km_inicial) AS km_rodado,
    ocorrencias
FROM registros_servico
WHERE ocorrencias IS NOT NULL
  AND TRIM(ocorrencias) <> ''
ORDER BY data_servico DESC;
