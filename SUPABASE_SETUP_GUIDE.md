# Supabase Configuration Guide for Team Ragnarok ASD App

## ❌ ERRORE CURRENT: Invalid API Key

L'applicazione sta attualmente mostrando l'errore "Invalid API key" perché la configurazione di Supabase non è corretta.

## 🔧 CORREZIONE RICHIESTA

### 1. Ottenere le Credenziali Corrette da Supabase

1. **Accedi al tuo progetto Supabase**:
   - Vai su [https://app.supabase.com](https://app.supabase.com)
   - Accedi al tuo account
   - Seleziona il progetto esistente o creane uno nuovo

2. **Trova le tue credenziali**:
   - Nel dashboard del progetto, vai su **Settings** → **API**
   - Troverai:
     - **Project URL** (inizia con `https://xxx.supabase.co`)
     - **anon public** key (inizia con `eyJ` ed è molto lungo)

### 2. Aggiornare il File env.json

Apri il file `env.json` nella root del progetto e sostituisci:

```json
{
  "SUPABASE_URL": "https://your-project-id.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...", 
  "OPENAI_API_KEY": "your-openai-api-key-here",
  "GEMINI_API_KEY": "your-gemini-api-key-here",
  "ANTHROPIC_API_KEY": "your-anthropic-api-key-here",
  "PERPLEXITY_API_KEY": "your-perplexity-api-key-here"
}
```

### 3. Formato Corretto delle Credenziali

**❌ ERRATO (attuale):**
- `SUPABASE_ANON_KEY`: `"TeamRagnarok@"`

**✅ CORRETTO:**
- `SUPABASE_URL`: `"https://xyzabcdef.supabase.co"`
- `SUPABASE_ANON_KEY`: `"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5emFiY2RlZiIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjg5ODY5ODk2LCJleHAiOjIwMDU0NDU4OTZ9..."`

### 4. Verifica della Configurazione

Dopo aver aggiornato le credenziali:

1. **Riavvia l'applicazione**
2. **Controlla i log della console** - dovresti vedere:
   - `✅ Supabase initialized successfully`
   - `✅ Authentication system initialized`
3. **Prova il login admin** con le credenziali corrette

### 5. Database Schema Verificato ✅

Il database è già configurato correttamente con:
- ✅ Tabella `user_profiles` con ruoli admin
- ✅ Tabella `admin_sessions` per la gestione delle sessioni
- ✅ Funzioni di sicurezza per verificare i permessi admin
- ✅ Politiche RLS (Row Level Security) configurate

### 6. Test di Verifica

Una volta aggiornate le credenziali, l'app dovrebbe:
- ✅ Inizializzare Supabase senza errori
- ✅ Consentire il login come admin
- ✅ Verificare automaticamente i permessi di amministratore
- ✅ Creare sessioni admin valide

## 🚨 IMPORTANTE

- **Mai condividere** le tue credenziali Supabase reali
- **Non committare** il file env.json con credenziali reali
- **Usa variabili d'ambiente** per la produzione

## 📞 Supporto

Se continui ad avere problemi dopo aver aggiornato le credenziali:
1. Verifica che il progetto Supabase sia attivo
2. Controlla che le tabelle siano state create correttamente
3. Verifica i permessi del database nel dashboard Supabase