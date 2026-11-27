-- =====================================================================
-- 03 - Index ajoutés
--
-- Exécuté automatiquement par Docker au premier démarrage, après le
-- chargement des données. Script repris de
-- docs/demarches/creation_index.md (section 6), qui justifie chaque index.
-- =====================================================================

CREATE INDEX IF NOT EXISTS idx_sessions_vehicule_debut ON urbanwatt.sessions_recharge (id_vehicule, debut_session);
CREATE INDEX IF NOT EXISTS idx_sessions_borne_debut    ON urbanwatt.sessions_recharge (id_borne, debut_session);
CREATE INDEX IF NOT EXISTS idx_sessions_debut          ON urbanwatt.sessions_recharge (debut_session);
ALTER TABLE urbanwatt.paiements ADD CONSTRAINT paiements_id_session_key UNIQUE (id_session);
CREATE INDEX IF NOT EXISTS idx_vehicules_client        ON urbanwatt.vehicules (id_client);
CREATE INDEX IF NOT EXISTS idx_paiements_en_attente    ON urbanwatt.paiements (date_paiement) WHERE statut = 'en_attente';

-- Met à jour les statistiques pour que PostgreSQL utilise les index
-- dès les premières requêtes.
ANALYZE;
