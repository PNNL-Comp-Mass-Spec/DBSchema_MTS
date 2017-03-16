
/*
 * Implements suggestions from http://dba.stackexchange.com/questions/36522/what-is-a-good-repeatable-way-to-calculate-maxdop-on-sql-server
 */

DECLARE @CoreCount int;
DECLARE @NumaNodes int;

SET @CoreCount = (SELECT i.cpu_count from sys.dm_os_sys_info i);
SET @NumaNodes = (
    SELECT MAX(c.memory_node_id) + 1 
    FROM sys.dm_os_memory_clerks c 
    WHERE memory_node_id < 64
    );

IF @CoreCount > 4 /* If less than 5 cores, don't bother. */
BEGIN
    DECLARE @MaxDOP int;

    /* 3/4 of Total Cores in Machine */
    SET @MaxDOP = @CoreCount * 0.75; 

    /* if @MaxDOP is greater than the per NUMA node
       Core Count, set @MaxDOP = per NUMA node core count
    */
    IF @MaxDOP > (@CoreCount / @NumaNodes) 
        SET @MaxDOP = (@CoreCount / @NumaNodes) * 0.75;

    /*
        Reduce @MaxDOP to an even number 
    */
    SET @MaxDOP = @MaxDOP - (@MaxDOP % 2);

    /* Cap MAXDOP at 8, according to Microsoft */
    IF @MaxDOP > 8 SET @MaxDOP = 8;

    SELECT 'Suggested MAXDOP = ' + CAST(@MaxDOP as varchar(max)) AS Recommendation, @CoreCount AS CoreCount, @NumaNodes AS NumaNodes;
END
ELSE
BEGIN
	Select 'Suggested MAXDOP = 0 since you have less than 4 cores total.' AS Value
	Union
    Select 'This is the default setting, you likely do not need to do anything' AS Value;
END

GO

/*************************************************************************
Author          :   Kin Shah
Purpose         :   Recommend MaxDop settings for the server instance
Tested RDBMS    :   SQL Server 2008R2

**************************************************************************/
declare @hyperthreadingRatio bit
declare @logicalCPUs int
declare @HTEnabled int
declare @physicalCPU int
declare @SOCKET int
declare @logicalCPUPerNuma int
declare @NoOfNUMA int

select @logicalCPUs = cpu_count -- [Logical CPU Count]
    ,@hyperthreadingRatio = hyperthread_ratio --  [Hyperthread Ratio]
    ,@physicalCPU = cpu_count / hyperthread_ratio -- [Physical CPU Count]
    ,@HTEnabled = case 
        when cpu_count > hyperthread_ratio
            then 1
        else 0
        end -- HTEnabled
from sys.dm_os_sys_info
option (recompile);

select @logicalCPUPerNuma = COUNT(parent_node_id) -- [NumberOfLogicalProcessorsPerNuma]
from sys.dm_os_schedulers
where [status] = 'VISIBLE ONLINE'
    and parent_node_id < 64
group by parent_node_id
option (recompile);

select @NoOfNUMA = count(distinct parent_node_id)
from sys.dm_os_schedulers -- find NO OF NUMA Nodes 
where [status] = 'VISIBLE ONLINE'
    and parent_node_id < 64

Declare @MAXDOP int
Declare @Reason varchar(128)

		
    If @logicalCPUs < 8 and @HTEnabled = 0
	Begin
		--- 8 or less processors and NO HT enabled
        Set @MaxDOP = @logicalCPUs
		Set @Reason = 'based on LogicalCPUs = ' + Cast(@logicalCPUs as varchar(8))
	End
	Else If @logicalCPUs >= 8 and @HTEnabled = 0
	Begin
		--- 8 or more processors and NO HT enabled
		Set @MaxDOP = 8
		Set @Reason = 'since more than 8 CPUs and no hyperthreading'
	End
	Else If @logicalCPUs >= 8 And @HTEnabled = 1 And @NoofNUMA = 1
	Begin
		--- 8 or more processors and HT enabled and NO NUMA
		Set @MaxDOP = @logicalCPUPerNuma / @physicalCPU 
		Set @Reason = 'Computed as LogicalCPUperNUMA / CPUs, ' + Cast(@logicalCPUPerNuma as varchar(8)) + ' / ' + Cast(@physicalCPU as varchar(8))
	End
	Else If @logicalCPUs >= 8 And @HTEnabled = 1 And @NoofNUMA > 1
	Begin
		DECLARE @Divisor float = @physicalCPU / @NoofNUMA
		--- 8 or more processors and HT enabled and NUMA
		Set @MaxDOP = @logicalCPUPerNuma / @Divisor 
		Set @Reason = 'Computed as LogicalCPUperNUMA / (CPUs / NUMA_Nodes), ' + Cast(@logicalCPUPerNuma as varchar(8)) + ' / ' + Cast(@Divisor as varchar(8))
	End
    Else
	Begin
		Set @MaxDOP = 8
		Set @Reason = 'Possible logic error; suggesting max suggested VALUE'
	End

	
	If @MaxDOP > 8
	Begin
		Set @MaxDOP = 8
		Set @Reason = @Reason + '; decreased to 8 since over 8'
	End

	-- Report the recommendations ....
	 SELECT 'MAXDOP setting should be : ' + CAST(@MaxDOP as varchar(3)) + ' (' + @reason + ')'
        as Recommendations,
		@logicalCPUs AS LogicalCPUs,
		@logicalCPUPerNuma AS LogicalCPUsPerNUMA,
		@HTEnabled AS HyperthreadingEnabled,
		@NoOfNUMA AS NUMA_Nodes,
		@physicalCPU as Physical_CPUs
go
