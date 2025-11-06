# Provider Vault - Mermaid Diagrams for README.md

## 1. System Architecture

```mermaid
graph TB
    subgraph "User Interface"
        CLI[CLI Module<br/>provider_vault_cli]
    end
    
    subgraph "Data Sources Layer"
        ORCH[Orchestrator<br/>Concurrent Coordinator]
        NPPES[NPPES Fetcher<br/>Real Data]
        MOCK_A[Mock Provider A<br/>Primary Care]
        MOCK_B[Mock Provider B<br/>Surgical]
        MOCK_C[Mock Provider C<br/>Mental Health]
    end
    
    subgraph "Business Logic"
        STORAGE[Storage Module<br/>Data Access Layer]
        PROVIDER[Provider Schema<br/>Ecto Model]
        VALIDATOR[Validators<br/>Data Validation]
    end
    
    subgraph "Data Persistence"
        DB[(PostgreSQL<br/>Database)]
    end
    
    CLI -->|fetch/refresh| ORCH
    CLI -->|add/list/search| STORAGE
    
    ORCH -.->|Task.async_stream| NPPES
    ORCH -.->|Task.async_stream| MOCK_A
    ORCH -.->|Task.async_stream| MOCK_B
    ORCH -.->|Task.async_stream| MOCK_C
    
    NPPES -->|15 providers| ORCH
    MOCK_A -->|15 providers| ORCH
    MOCK_B -->|15 providers| ORCH
    MOCK_C -->|15 providers| ORCH
    
    ORCH -->|bulk insert| STORAGE
    STORAGE -->|uses| PROVIDER
    STORAGE -->|uses| VALIDATOR
    STORAGE -->|Ecto queries| DB
    
    style ORCH fill:#e1f5ff
    style NPPES fill:#fff3cd
    style MOCK_A fill:#d4edda
    style MOCK_B fill:#d4edda
    style MOCK_C fill:#d4edda
    style DB fill:#f8d7da
```

---

## 2. Concurrent Data Fetching Flow

```mermaid
sequenceDiagram
    actor User
    participant CLI
    participant Orchestrator
    participant NPPES
    participant MockA as Mock A
    participant MockB as Mock B
    participant MockC as Mock C
    participant Storage
    participant DB as PostgreSQL

    User->>CLI: ./provider_vault_cli fetch
    CLI->>Orchestrator: fetch_and_store()
    
    Note over Orchestrator: Task.async_stream<br/>max_concurrency: 4
    
    par Concurrent Fetching
        Orchestrator->>NPPES: fetch()
        Orchestrator->>MockA: fetch()
        Orchestrator->>MockB: fetch()
        Orchestrator->>MockC: fetch()
    end
    
    Note over NPPES,MockC: All sources fetch<br/>simultaneously!
    
    NPPES-->>Orchestrator: 15 providers (523ms)
    MockA-->>Orchestrator: 15 providers (687ms)
    MockB-->>Orchestrator: 15 providers (891ms)
    MockC-->>Orchestrator: 15 providers (742ms)
    
    Note over Orchestrator: Total: ~900ms<br/>(not 2300ms sequential!)
    
    loop For each source
        Orchestrator->>Storage: insert_provider(data)
        Storage->>DB: INSERT INTO providers
        DB-->>Storage: {:ok, provider}
    end
    
    Orchestrator-->>CLI: {:ok, stats}
    CLI-->>User: ✓ 60 providers stored
```

---

## 3. Database Schema

```mermaid
erDiagram
    PROVIDERS {
        bigint id PK
        string npi UK "10 digits, unique"
        string first_name
        string last_name
        string credential "MD, DO, NP, PA"
        string specialty
        string address
        string city
        string state "2 letters"
        string zip
        string phone
        string name "Legacy: last, first"
        string taxonomy "Legacy"
        timestamp inserted_at
        timestamp updated_at
    }
    
    PROVIDERS ||--o{ SOURCES : "fetched_from"
    
    SOURCES {
        string source_name
        string npi_range
        string focus
    }
```

**NPI Ranges by Source:**
- NPPES: 1500000001-1500000015
- Mock A (Primary Care): 2000000001-2000000015
- Mock B (Surgical): 3000000001-3000000015
- Mock C (Mental Health): 4000000001-4000000015

---

## 4. CLI Command Structure

```mermaid
graph LR
    subgraph "Data Fetching Commands"
        FETCH[fetch]
        REFRESH[refresh]
    end
    
    subgraph "Provider Management"
        ADD[add]
        UPDATE[update]
        DELETE[delete]
        SHOW[show]
    end
    
    subgraph "Query Commands"
        LIST[list]
        SEARCH[search]
        STATS[stats]
    end
    
    subgraph "Import/Export"
        IMPORT[import]
        EXPORT[export]
        CLEAR[clear]
    end
    
    FETCH -->|Orchestrator| CONCURRENT[Concurrent<br/>Fetch]
    REFRESH -->|Clear + Fetch| CONCURRENT
    
    ADD -->|Storage| DB[(Database)]
    UPDATE -->|Storage| DB
    DELETE -->|Storage| DB
    SHOW -->|Storage| DB
    
    LIST -->|Storage| DB
    SEARCH -->|Storage| DB
    STATS -->|Storage| DB
    
    IMPORT -->|CSV Parser| DB
    EXPORT -->|CSV Writer| FILE[CSV File]
    CLEAR -->|Storage| DB
    
    style FETCH fill:#e1f5ff
    style REFRESH fill:#e1f5ff
    style CONCURRENT fill:#d4edda
```

---

## 5. Module Dependencies

```mermaid
graph TD
    subgraph "Application Layer"
        APP[ProviderVaultCli.Application]
        RUNNER[MixRunner<br/>escript entry]
    end
    
    subgraph "CLI Layer"
        CLI[ProviderVault.CLI]
    end
    
    subgraph "Data Sources"
        ORCH[Orchestrator]
        NPPES[NPPESFetcher]
        MOCKA[MockProviderA]
        MOCKB[MockProviderB]
        MOCKC[MockProviderC]
    end
    
    subgraph "Business Logic"
        STORAGE[Storage]
        PROVIDER[Provider Schema]
        VALIDATOR[Validators]
        REPO[Repo]
    end
    
    subgraph "External Dependencies"
        ECTO[Ecto/Ecto.SQL]
        POSTGREX[Postgrex]
        NIMBLE[NimbleCSV]
    end
    
    APP --> REPO
    RUNNER --> CLI
    
    CLI --> ORCH
    CLI --> STORAGE
    
    ORCH --> NPPES
    ORCH --> MOCKA
    ORCH --> MOCKB
    ORCH --> MOCKC
    ORCH --> STORAGE
    
    STORAGE --> PROVIDER
    STORAGE --> VALIDATOR
    STORAGE --> REPO
    
    REPO --> ECTO
    REPO --> POSTGREX
    STORAGE -.-> NIMBLE
    
    style ORCH fill:#e1f5ff
    style STORAGE fill:#fff3cd
```

---

## 6. Data Flow: Fetch Operation

```mermaid
flowchart TD
    START([User: ./provider_vault_cli fetch])
    
    START --> CLI_FETCH[CLI.handle_fetch/0]
    CLI_FETCH --> ORCH_FETCH[Orchestrator.fetch_and_store/0]
    
    ORCH_FETCH --> ASYNC[Task.async_stream<br/>max_concurrency: 4]
    
    ASYNC --> PAR_START{Concurrent<br/>Execution}
    
    PAR_START -.->|Process 1| NPPES_FETCH[NPPES.fetch/0]
    PAR_START -.->|Process 2| MOCKA_FETCH[MockA.fetch/0]
    PAR_START -.->|Process 3| MOCKB_FETCH[MockB.fetch/0]
    PAR_START -.->|Process 4| MOCKC_FETCH[MockC.fetch/0]
    
    NPPES_FETCH --> NPPES_DATA[15 providers]
    MOCKA_FETCH --> MOCKA_DATA[15 providers]
    MOCKB_FETCH --> MOCKB_DATA[15 providers]
    MOCKC_FETCH --> MOCKC_DATA[15 providers]
    
    NPPES_DATA --> COLLECT[Collect Results]
    MOCKA_DATA --> COLLECT
    MOCKB_DATA --> COLLECT
    MOCKC_DATA --> COLLECT
    
    COLLECT --> PROCESS[Process & Store]
    
    PROCESS --> LOOP{For each<br/>provider}
    
    LOOP -->|validate| CHANGESET[Provider.changeset/2]
    CHANGESET --> INSERT[Repo.insert/1]
    INSERT --> DB[(PostgreSQL)]
    
    DB -->|success| COUNT[Increment stored count]
    DB -->|error| SKIP[Increment failed count]
    
    COUNT --> LOOP
    SKIP --> LOOP
    
    LOOP -->|done| STATS[Generate Statistics]
    STATS --> RETURN[Return {:ok, stats}]
    
    RETURN --> CLI_DISPLAY[CLI displays summary]
    CLI_DISPLAY --> END([User sees results])
    
    style ASYNC fill:#e1f5ff
    style PAR_START fill:#d4edda
    style DB fill:#f8d7da
```

---

## 7. Concurrent vs Sequential Comparison

```mermaid
gantt
    title Concurrent vs Sequential Execution
    dateFormat X
    axisFormat %Lms
    
    section Sequential (2,746ms)
    NPPES (586ms)    :s1, 0, 586
    MockA (412ms)    :s2, after s1, 412
    MockB (866ms)    :s3, after s2, 866
    MockC (434ms)    :s4, after s3, 434
    
    section Concurrent (891ms)
    NPPES (586ms)    :c1, 0, 586
    MockA (412ms)    :c2, 0, 412
    MockB (866ms)    :c3, 0, 866
    MockC (434ms)    :c4, 0, 434
```

**Performance Gain:** 3x faster with concurrency!

---

## 8. NPPES Fetcher State Machine (Production Mode)

```mermaid
stateDiagram-v2
    [*] --> TestMode: @test_mode == true
    [*] --> ProductionMode: @test_mode == false
    
    TestMode --> GenerateSample: Generate in memory
    GenerateSample --> ReturnProviders
    
    ProductionMode --> Download: Download ZIP (2-3 GB)
    Download --> Extract: Unzip CSV
    Extract --> Parse: Parse & validate
    Parse --> Sample: Random sample 15 from 10k
    Sample --> Cleanup: Delete ZIP & CSV
    Cleanup --> ReturnProviders
    
    ReturnProviders --> [*]
    
    note right of Download
        Uses :httpc
        Creates temp file
    end note
    
    note right of Sample
        Enum.take(10_000)
        Enum.take_random(15)
    end note
    
    note right of Cleanup
        File.rm(zip_path)
        File.rm(csv_path)
    end note
```

---

## How to Use in README.md

Simply copy the Mermaid code blocks into your README.md:

````markdown
# Provider Vault

## Architecture Overview

```mermaid
graph TB
    subgraph "User Interface"
        CLI[CLI Module]
    end
    ...
```

## Concurrent Data Flow

```mermaid
sequenceDiagram
    actor User
    participant CLI
    ...
```
````

GitHub automatically renders Mermaid diagrams! 🎨
