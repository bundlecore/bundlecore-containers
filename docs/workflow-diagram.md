# Trivy Security Scan Workflow - Detailed Flow Diagram

## Complete Workflow Flow

```mermaid
flowchart TD
    Start([Workflow Triggered]) --> Trigger{Trigger Type}
    
    Trigger -->|Scheduled| Schedule[First Sunday of Month<br/>2:00 AM UTC]
    Trigger -->|Manual| Manual[Manual Trigger<br/>with Options]
    
    Schedule --> CheckRecent[Check Recent Scan Results]
    Manual --> CheckRecent
    
    CheckRecent --> RecentAPI[Query GitHub API<br/>for Recent Runs]
    RecentAPI --> RecentFound{Recent Success<br/>Found?}
    
    RecentFound -->|Yes| DownloadArtifacts[Download Recent Artifacts]
    RecentFound -->|No| CheckFailed[Check Failed Runs<br/>for Partial Results]
    
    CheckFailed --> PartialFound{Partial Results<br/>Available?}
    PartialFound -->|Yes| DownloadPartial[Download Partial Artifacts]
    PartialFound -->|No| FreshScan[Fresh Scan Required]
    
    DownloadArtifacts --> SecurityScan[Container Security Scan]
    DownloadPartial --> SecurityScan
    FreshScan --> SecurityScan
    
    SecurityScan --> DiscoverImages[Discover Container Images<br/>from products/bfx/*]
    DiscoverImages --> ImageCount{Images Found?}
    
    ImageCount -->|No| NoImages[❌ No Images Found<br/>Workflow Fails]
    ImageCount -->|Yes| CreateMapping[Create Tool-Image Mapping]
    
    CreateMapping --> TrivyScan[Trivy Security Scan Job]
    
    TrivyScan --> ReuseCheck{Reuse Available?}
    
    ReuseCheck -->|Yes| PrepareRecent[Prepare Recent Results]
    ReuseCheck -->|No| BatchScan[Batch Scan Images]
    
    PrepareRecent --> CopyResults[Copy Downloaded Results<br/>to trivy-results/]
    CopyResults --> OrganizeResults
    
    BatchScan --> ScanLoop[Scan Each Image<br/>with Trivy]
    ScanLoop --> ScanResult{Scan Success?}
    
    ScanResult -->|Success| SaveResult[Save JSON Result<br/>Update Progress]
    ScanResult -->|Failure| LogFailure[Log Failure<br/>Continue Next]
    
    SaveResult --> UploadProgress[Upload Artifacts<br/>Every 5 Scans]
    LogFailure --> MoreImages{More Images?}
    UploadProgress --> MoreImages
    
    MoreImages -->|Yes| ScanLoop
    MoreImages -->|No| FinalUpload[Upload Final Artifacts<br/>trivy-scan-results]
    
    FinalUpload --> OrganizeResults[Organize Scan Results by Tool]
    
    OrganizeResults --> ProcessTools[Process Each Tool<br/>Group by Versions]
    ProcessTools --> CreateToolJSON[Create Tool-Specific<br/>JSON Files]
    CreateToolJSON --> UploadOrganized[Upload Organized Results<br/>organized-results]
    
    UploadOrganized --> CreatePR[Create Pull Request]
    
    CreatePR --> BackupDir[Backup organized-results<br/>to /tmp/]
    BackupDir --> GitOps[Git Operations<br/>Branch Management]
    
    GitOps --> BranchExists{Branch Exists?}
    BranchExists -->|Yes| UpdateBranch[Switch to Branch<br/>Reset to Main]
    BranchExists -->|No| CreateBranch[Create New Branch]
    
    UpdateBranch --> RestoreBackup[Restore organized-results<br/>from Backup]
    CreateBranch --> RestoreBackup
    
    RestoreBackup --> CopyToTools[Copy Results to<br/>bfx/*/trivy-scan-results.json]
    CopyToTools --> DirectoryMatch[Smart Directory Matching<br/>Fuzzy + Reverse Match]
    
    DirectoryMatch --> MatchFound{Directory<br/>Match Found?}
    MatchFound -->|Yes| CopyFile[Copy Scan Results<br/>Git Add File]
    MatchFound -->|No| SkipTool[Skip Tool<br/>Log Warning]
    
    CopyFile --> MoreTools{More Tools?}
    SkipTool --> MoreTools
    
    MoreTools -->|Yes| CopyToTools
    MoreTools -->|No| CommitChanges[Git Commit Changes]
    
    CommitChanges --> PushBranch[Push Branch<br/>Handle Conflicts]
    PushBranch --> PRExists{PR Exists?}
    
    PRExists -->|Yes| UpdatePR[Update Existing PR<br/>with New Results]
    PRExists -->|No| CreateNewPR[Create New PR<br/>with Scan Results]
    
    UpdatePR --> AddLabels[Attempt to Add Labels<br/>security, automated, trivy-scan]
    CreateNewPR --> AddLabels
    
    AddLabels --> LabelResult{Labels Added?}
    LabelResult -->|Success| LabelsOK[✅ Labels Added]
    LabelResult -->|Failed| LabelsSkip[⚠️ Labels Skipped<br/>Continue Anyway]
    
    LabelsOK --> Success[🎉 Workflow Success]
    LabelsSkip --> Success
    
    Success --> Summary[Display Summary<br/>- Tools Scanned<br/>- PR Created<br/>- Artifacts Saved]
    
    Summary --> End([Workflow Complete])
    NoImages --> End
    
    %% Styling
    classDef successClass fill:#d4edda,stroke:#155724,stroke-width:2px
    classDef errorClass fill:#f8d7da,stroke:#721c24,stroke-width:2px
    classDef processClass fill:#e2e3e5,stroke:#383d41,stroke-width:2px
    classDef decisionClass fill:#fff3cd,stroke:#856404,stroke-width:2px
    
    class Success,LabelsOK,Summary successClass
    class NoImages errorClass
    class CheckRecent,SecurityScan,TrivyScan,OrganizeResults,CreatePR processClass
    class RecentFound,PartialFound,ImageCount,ReuseCheck,ScanResult,MoreImages,MoreTools,BranchExists,MatchFound,PRExists,LabelResult decisionClass
```

## Artifact Flow Diagram

```mermaid
flowchart LR
    subgraph "Scan Phase"
        A[Individual Scans] --> B[trivy-*.json files]
        B --> C[trivy-scan-results<br/>artifact]
        B --> D[trivy-scan-results-partial<br/>artifact]
    end
    
    subgraph "Organization Phase"
        E[Tool Grouping] --> F[*-trivy-scan-results.json]
        F --> G[organized-results<br/>artifact]
    end
    
    subgraph "Final Phase"
        H[All Files] --> I[trivy-scan-results-final<br/>artifact]
    end
    
    subgraph "Reuse Logic"
        C --> J{Next Run}
        D --> J
        G --> J
        I --> J
        J --> K[Download & Reuse<br/>⚡ 30 seconds vs 3 hours]
    end
    
    subgraph "Retention"
        C --> L[30 days]
        D --> L
        G --> M[90 days]
        I --> M
    end
    
    %% Styling
    classDef artifactClass fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
    classDef reuseClass fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef retentionClass fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    
    class C,D,G,I artifactClass
    class J,K reuseClass
    class L,M retentionClass
```

## Error Handling Flow

```mermaid
flowchart TD
    Error[Error Occurred] --> ErrorType{Error Type}
    
    ErrorType -->|Network| NetworkRetry[Retry with<br/>Exponential Backoff]
    ErrorType -->|Scan Failure| IndividualFail[Log Individual Failure<br/>Continue with Next Image]
    ErrorType -->|Directory Missing| FuzzyMatch[Try Fuzzy Directory<br/>Matching]
    ErrorType -->|Branch Conflict| BranchHandle[Handle Existing Branch<br/>Force Push with Lease]
    ErrorType -->|PR Exists| UpdateExisting[Update Existing PR<br/>Instead of Creating New]
    ErrorType -->|Label Missing| SkipLabels[Skip Label Addition<br/>Continue Workflow]
    ErrorType -->|Artifact Missing| TryAlternative[Try Alternative<br/>Artifact Sources]
    
    NetworkRetry --> RetrySuccess{Retry Success?}
    RetrySuccess -->|Yes| Continue[Continue Workflow]
    RetrySuccess -->|No| LogError[Log Error<br/>Continue if Possible]
    
    IndividualFail --> Continue
    FuzzyMatch --> MatchFound{Match Found?}
    MatchFound -->|Yes| Continue
    MatchFound -->|No| SkipTool[Skip Tool<br/>Log Warning]
    
    BranchHandle --> Continue
    UpdateExisting --> Continue
    SkipLabels --> Continue
    TryAlternative --> Continue
    SkipTool --> Continue
    LogError --> Continue
    
    Continue --> WorkflowContinues[Workflow Continues<br/>with Remaining Tasks]
    
    %% Styling
    classDef errorClass fill:#ffebee,stroke:#c62828,stroke-width:2px
    classDef recoveryClass fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
    classDef continueClass fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    
    class Error,ErrorType,RetrySuccess,MatchFound errorClass
    class NetworkRetry,IndividualFail,FuzzyMatch,BranchHandle,UpdateExisting,SkipLabels,TryAlternative recoveryClass
    class Continue,WorkflowContinues continueClass
```

## Performance Comparison

```mermaid
gantt
    title Workflow Execution Time Comparison
    dateFormat X
    axisFormat %s
    
    section Fresh Scan
    Image Discovery    :0, 300
    Trivy Database     :300, 600
    Batch Scanning     :600, 10800
    Organize Results   :10800, 11100
    Create PR          :11100, 11400
    
    section Artifact Reuse
    Check Recent       :0, 5
    Download Artifacts :5, 15
    Organize Results   :15, 25
    Create PR          :25, 30
    
    section Partial Resume
    Check Progress     :0, 5
    Resume Scanning    :5, 3605
    Organize Results   :3605, 3905
    Create PR          :3905, 4205
```

---

*These diagrams provide a comprehensive view of the Trivy Security Scan workflow, showing all decision points, error handling, and optimization strategies.*