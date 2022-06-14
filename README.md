# Flowchart - Query performance tuning 

This flowchart is meant to address a performance issue that applications may experience in conjunction with SQL Server.

```mermaid
flowchart TB
    Starting(Starting the performance tuning) --> 
    IsolateTsql{Have you identified and isolated <br> the process with the problem?}
        IsolateTsql --> | Yes | IsolateTsql_Yes[Determine app source of code]
        IsolateTsql --> | No | IsolateTsql_No["Use the <b><i>#quot;monitoring and isolating <br>a process causing problems#quot;</i></b> <br>workflow to identify the process"]
    IsolateTsql_No --> Starting
    IsolateTsql_Yes --> ExecPattern{Check with app owner.<br>Is this execution <br>pattern expected?}
        ExecPattern --> | Yes/Unknown | ExpectedPerformance{Do you know what is the expected <br> performance and number of <br>exec. per minute of this code?}
        ExpectedPerformance --> | Yes | ContinueOptimization["Continue with optimization"]
        ExpectedPerformance --> | No | MonitoringTool{"Is there any monitoring <br>tool capturing<br> exec. stats data for this <br>code?"}
            MonitoringTool --> | Yes | MonitoringTool_Yes[Identify the exec. stats of the <br>code to use it as a bench] --> FoundBench
            MonitoringTool --> | No | InstanceAccess{Do you have access to<br> the SQL instance running<br> the process?}
            InstanceAccess --> | Yes | QueryStore{Is it query store available<br> and enabled for this DB?}
                QueryStore --> | Yes | QueryStore_Yes[Use QS dmvs to get exec. stats of the <br>code to use it as a bench]
                QueryStore_Yes --> FoundBench
                QueryStore --> | No | PlanCacheDMV[Use sys.dm_exec_query_stats to get<br> exec. stats of the code to <br>use it as a bench]
                PlanCacheDMV --> FoundBench{Were you able to identify <br>the exec. stats?}
            FoundBench --> | Yes | FoundBench_Yes[Double check exec. stats numbers with app <br>owner to confirm this pattern is expected <br>and set improvement expectations]
                FoundBench_Yes --> ContinueOptimization
            FoundBench --> | No | Profiler_XE{"Can you run the process now <br>and capture exec. stats using <br>Profiler or a xEvent?"}
                Profiler_XE --> | Yes or process runs often | Profiler_XE_Yes[Start a trace to capture the exec. stats<br> Make sure you've got permission to start the <br>trace and used the correct filters]
                Profiler_XE --> | No | RunInTest_1{Is there a test environment <br>available to run the process?}
                    RunInTest_1 --> | Yes | Profiler_XE_Yes --> FoundBench_Yes
                    RunInTest_1 --> | No | RunInTest_No[Check with client what is the <br>expectation for the optimization and <br>use it as a bench] --> FoundBench_Yes
        ExecPattern --> | No | FixApp[Fix the issue in app to correct the pattern]
        FixApp --> FixAppQ{Did this fix <br>the problem?} 
            FixAppQ --> | Yes | FixAppQ_Yes["That was easy, all good! #128588;"]
            FixAppQ --> | No | ExpectedPerformance
        ContinueOptimization --> 
        CheckResources{"Is there an unexpected spike<br> in the workload or resource <br>usage(batch requests/sec, <br>CPU, disk and etc) that<br> could explain the problem?"}
        CheckResources --> | Yes | CheckResources_Yes["Use the <b><i>#quot;General slowness#quot;</i></b> <br>workflow to resolve this problem"]
        CheckResources --> | No | WhereToTestIt
        WhereToTestIt{Is there a test environment <br>available to run some tests<br> of the process?}
            WhereToTestIt --> | Yes | IsTestUpdated{"Is it DB and app in test env. <br>the same (SQL version, edition, <br>number of rows tables, schema<br> and app release) as in prod?"} 
                IsTestUpdated --> | Yes | ContinueInTest[Continue optimization on <br>test environment] --> StartingOptimization
                IsTestUpdated --> | No | IsTestUpdated_No_1[Ask client to refresh the test env.] --> IsTestUpdated_No_2[A quick alternative would be use a cloned<br> DB or export the schema including <br>the stats] --> ContinueInTest
            WhereToTestIt --> | No | TestInProd[Explain the client the risks<br> of doing optimization in prod <br>and ask for approval to move<br> forward]
        TestInProd --> GotApprovalToOptimizeInProd{Did you get approval <br>to work on high risk mode and <br>optimize the code in prod?}
        GotApprovalToOptimizeInProd --> | Yes | StartingOptimization[Continue with optimization]
        GotApprovalToOptimizeInProd --> | No | GotApprovalToOptimizeInProd_No[TODO:add steps to check <br>the t-sql...]
    StartingOptimization -->
    AppOrBDProblem{Based on total <br>process duration, is it <br>percentual of time spend <br>on SQL relevant?}
        AppOrBDProblem --> | Yes | IsolateSlowestStatement[Based on total process duration <br>and exec. stats, if possible, isolate the <br>most resource consuming t-sql <br>code at the <b>statement</b> level]
        AppOrBDProblem --> | No | FixAppAppOrBDProblem_No{Is it possible to <br>optimize the <br>code on app?}
            FixAppAppOrBDProblem_No --> | Yes |FixedOnApp{Did this fix <br>the problem?} 
                FixedOnApp --> | Yes | FixedOnApp_Yes["All good! #128588;"]
                FixedOnApp --> | No | IsolateSlowestStatement
            FixAppAppOrBDProblem_No --> | No | IsolateSlowestStatement
        AppOrBDProblem --> | I don't know | IdentifyCode[Use the exec. stats you have<br> or, if necessary run the process<br> again and use a trace <br>to capture the exec. stats <br> to answer this question]
        AppOrBDProblem --> | Not really, but client <br>wants to make it run as <br>fast as possible on SQL | IsolateSlowestStatement
    IsolateSlowestStatement --> CopyEstimatedPlan[If possible/available, use QS, <br>PlanCache or trace to capture the <br>statement execution plan] 
    IsolateSlowestStatement --> | I don't know how to do it | IdentifyCode
    CopyEstimatedPlan -->
    ActualExecPlan{Is it possible to run <br>the statement<br> on SSMS?}
        ActualExecPlan --> | Yes | ActualExecPlanYes[Run the statement on <br>SSMS and if possible capture actual<br> execution plan]
        ActualExecPlanYes -->  ActualExecPlanYes2[Depending on the number of <br>statements in the code, you may need<br> to capture the actual exec plan via <br>trace/xEvent]
        ActualExecPlan --> | Yes but I don't want to<br> wait for it to run <br>because it takes<br> too much time | ActualExecPlanNo[Type the statement on <br>SSMS and capture estimated<br> execution plan]
        ActualExecPlan --> | No | ActualExecPlanNo
    ActualExecPlanYes2 --> FasterOnSSMS{Was it faster <br> on SSMS?}
    FasterOnSSMS --> | Yes | FasterOnSSMS_Yes["Examine app for result handling. <br>App may be doing a RBAR (Row-By-Agonizing-Row),<br> if that's the case you'll probably see a<br> async_network_io wait. Check if app is<br> unnecessarily opening the connection using MARS."] -->
    CheckParameterization{Is this an ad-hoc <br> or a parameterized <br>statement?} 
        CheckParameterization --> | Ad-hoc | AdHoc{Does the number of <br>read/returned rows varies<br> a lot depending on<br> the input params?}
            AdHoc --> | Yes | AdHocYes["Add option(recompile) <br>hint on statement and try again"]
            AdHocYes --> OptionRecompileFix{Did this create a <br>better plan and <br>solved the problem?}
                OptionRecompileFix --> | Yes | ReviewRecompilationCost[Check if it is worthy to pay <br>for extra cost of compilation time<br> for each execution. Cost may be too<br> high depending on number of executions<br> of this statement] --> OptionRecompileFixYes{"Is it possible to <br>change the app <br>code to use an <br>option(recompile)?"}
                    OptionRecompileFixYes --> | Yes | OptionRecompileFixAllGood["All good! #128588;"]
                    OptionRecompileFixYes --> | No | OptionRecompileFixPlanGuide["Force option(recompile)<br> via plan-guide"]
                    OptionRecompileFixPlanGuide --> OptionRecompileFixAllGood["All good! #128588;"]
                    OptionRecompileFixYes --> | Compilation <br> cost is too high | CostTooHigh["Check other options<br> to fix PSP<br> e.g. option(optimize for), <br>option(optimize for unknown) <br>and etc"] --> OptionRecompileFix
                OptionRecompileFix --> | No | PSP_DiffPlan
            AdHoc --> | No | AdHocNo{"Is it possible to <br>change the app <br>code to use parameterized <br> queries?"}
                AdHocNo--> | Yes | DidWeFixItAdhoc1{Did this fix <br>the problem?}
                    DidWeFixItAdhoc1 --> | Yes | DidWeFixItAdhoc1_Yes["All good! #128588;"]
                    DidWeFixItAdhoc1 --> | No | ContinueWithNextOptimization
                AdHocNo--> | No | ForcedParamViaPlanGuide["Force parameterization<br> via plan-guide"]
                    ForcedParamViaPlanGuide --> DidWeFixItAdhoc2{Did this fix <br>the problem?}
                    DidWeFixItAdhoc2 --> | Yes | DidWeFixItAdhoc1_Yes["All good! #128588;"]
                    DidWeFixItAdhoc2 --> | No | ContinueWithNextOptimization
        CheckParameterization --> | Parameterized | PSP_DiffPlan
    PSP_DiffPlan{Compare the execution<br> plan with plan <br>generated by the<br> application. <br>Are the plans diff?}
        PSP_DiffPlan --> | Yes | PSP_DiffPlan_Yes{"Are you using exactly the <br>same parameter(s) value(s) <br>that app is using?"}
            PSP_DiffPlan_Yes --> | Yes | PSP_DiffPlan_Yes_1[Check if the connection SET <br> options are the same <br>on app and SSMS] --> PSP_DiffPlan
            PSP_DiffPlan_Yes --> | No | PSP_DiffPlan_Yes_2[Try again using the same <br> param values that <br>app is using] --> FasterOnSSMS & ContinueWithNextOptimization
        PSP_DiffPlan --> | No or <br> not possible to check | ContinueWithNextOptimization[Continue with next optimization]
    FasterOnSSMS --> | No | ContinueWithNextOptimization
    ContinueWithNextOptimization --> 
    CheckBadCardEstimations[Check if there are bad cardinality estimations. <br>Compare estimated vs actual number of<br> rows of plan operators] -->
    CheckStats[Make sure that statistics for all tables<br> used in the statement are up to date<br> and providing useful information.<br> If necessary run an update statistics <br>with fullscan] --> DidWeFixIt1{Did this fix <br>the problem?} 
            DidWeFixIt1 --> | Yes | DidWeFixIt1_Yes["All good! #128588;"]
            DidWeFixIt1 --> | No | CheckMissingIndexes
    CheckMissingIndexes[Initial index check: <br>Check if there are any obvious <br>missing index that could help <br>with the performance] --> DidWeFixIt2{Did this fix <br>the problem?} 
            DidWeFixIt2 --> | Yes | DidWeFixIt2_Yes["All good! #128588;"]
            DidWeFixIt2 --> | No | IdentifyMostExpensiveOperations
    IdentifyMostExpensiveOperations["Run the code with #quot; SET STATISTICS IO, CPU ON #quot; <br> and actual exec plan to use a combination of reads, CPU, <br>duration metrics to identify the most expensive operation"] -->
    CheckExecPlan["Review the most commom issues in a exec plan"] -->
    CheckScans["Is there any scan that shouldn't be there? <br> The most commom cases are the ones reading <br>a lot of rows and to return just a few"] -->
    CheckKeyLookups["Is there any key/rid lookups? <br> It is easy to remove them by  adding the output and <br>predicate columns in a existing index"] -->
    CheckJoins["Review the join order algorithms. Are they correct? <br> Usually, nested loop is used for a few rows <br>and hash/merge to read many rows"] -->
    CheckJoinsHints1[Check if there are unecessary hints <br>forcing a query plan] -->
    CheckJoinsHints2[Remove hints and try again<br> to see if QO was able to create<br> a better plan] -->
    CheckIndexAccess{Is it query returning a <br>lot of rows or doing <br>unavoidable large scans?}
        CheckIndexAccess --> | Yes | CheckParallelism[Review paralellism and make sure there are<br> no paralelism blockers. Also make sure that MAXDOP <br>is set correctly, you may want to increase it via hint to give<br> more resources to the query] --> 
        CheckParallelismBalance[Review paralelism balance and re-write<br> the query to avoid unbalanced parallel operators.] --> CheckBatchRowMode[Review read mode to confirm that batch mode is used<br> where possible. If necessary, create a dummy filtered<br> nonclustered columnstore index to enable batch mode] -->
        CreateIndexes[Create ColumnStore indexes or covered indexes <br>to support the query. ColumnStore is your fastest option to support<br> scan in a large number of rows.]
        CheckIndexAccess --> | No | QueryComplex
    QueryComplex{Is it query <br>too complex?}
        QueryComplex --> | Yes | RewriteQuery[Rewrite the query to simplify it<br> if necessary, use temporary tables to help you with it]
        QueryComplex --> | No | ScalarFunctions
    ScalarFunctions[Review cost of Scalar Functions and if <br>necessary, re-write them as inline functions] -->
    UnecessaryOperations[Review the query and exec plan to avoid unecessary <br>operations like access to same object many times. <br>If necessary re-write the query to avoid this] --> 
    CheckSpills[Review memory consumer operators and make<br> sure grant is enough to process all rows in-memory<br> and avoid spills. If necessary use techniques to increase <br>memory grant] --> 
    CheckNonSargs[Review non-sarg operations that may causing bad <br>estimations or impacting on index usage] -->
    CheckImplicitConversion[Check if there are implicit conversions causing bad <br>estimations or impacting on index usage.<br> The most common is the conversion from<br> a varchar column using a nvarchar variable] -->
    OtherCheck[If I put it all here, the list may be HUGE]
