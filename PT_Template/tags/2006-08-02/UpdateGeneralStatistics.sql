SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UpdateGeneralStatistics]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[UpdateGeneralStatistics]
GO



CREATE Procedure dbo.UpdateGeneralStatistics
/****************************************************
**
**	Desc: Gathers several general statistics from mass
**        tag database and updates their values in the
**        T_General_Statistics table
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**	
**
**		Auth: grk
**		Date: 08/5/2003
**			  07/22/2004 mem - Removed reference to T_Master_TIC
**			  09/06/2004 mem - Added statistics on number of analyses with each Process_State value
**			  10/23/2004 mem - Now storing T_Process_Config data as Category 'Configuration Settings'
**			  02/04/2005 mem - Switched to using V_Table_Row_Counts for row count stats
**			  03/07/2005 mem - Updated to reflect changes to T_Process_Config that now use just one column to identify a configuration setting type
**    
*****************************************************/
As
	set nocount on

	declare @result int

	-- Clear general statistics table
	--
	DELETE FROM T_General_Statistics
	
	-- Header row
	INSERT INTO T_General_Statistics
	SELECT 'General' AS category, 'Last Updated' AS label, GetDate() AS value
	
	-- Organism
	--
	INSERT INTO T_General_Statistics
	SELECT	'Organism' AS category, 
			'Name' AS label, PDB_Organism as value
	FROM	MT_Main.dbo.T_Peptide_Database_List
	WHERE	PDB_Name = DB_Name()
	
	-- Peptides
	--
	INSERT INTO T_General_Statistics
	SELECT	'Peptides' AS category,
			'Peptide Identifications' AS label, TableRowCount AS Value
	FROM V_Table_Row_Counts
	WHERE TableName = 'T_Peptides'


	-- total sequences
	--
	INSERT INTO T_General_Statistics
	SELECT	'Peptides' AS category, 
			'Sequences' AS label, TableRowCount AS Value
	FROM V_Table_Row_Counts
	WHERE TableName = 'T_Sequence'


	-- update dataset counts
	--
	INSERT INTO T_General_Statistics
	SELECT	'Primary Datasets' AS category, 
			'Number of Datasets' AS label, TableRowCount AS Value
	FROM V_Table_Row_Counts
	WHERE TableName = 'T_Datasets'
	
	-- update analyses counts
	--
	-- total MS/MS analyses
	--
	INSERT INTO T_General_Statistics
	SELECT	'Primary Analyses' AS category, 
			'Number of MS/MS Analyses' AS label, TableRowCount AS Value
	FROM V_Table_Row_Counts
	WHERE TableName = 'T_Analysis_Description'


	-- update analysis tool counts
	--
	INSERT INTO T_General_Statistics
	SELECT 'Total Analyses by Analysis Tool' AS category, 
		 Analysis_Tool AS label, COUNT(*) AS value
	FROM T_Analysis_Description 
	GROUP BY Analysis_Tool


	-- update process state counts
	--
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT Category, Label, COUNT(Job) AS Value
	FROM (	SELECT 'Total Analyses by Process State' AS category, 
					T_Process_State.ID, 
					CONVERT(varchar(9), T_Process_State.ID) + ' - ' + T_Process_State.Name AS label, 
					T_Analysis_Description.Job
			FROM T_Process_State INNER JOIN T_Analysis_Description ON 
				 T_Process_State.ID = T_Analysis_Description.Process_State
		 ) AS LookupQ
	GROUP BY category, ID, label
	ORDER BY ID


	-- import thresholds and other config info from T_Process_Config
	-- 
	INSERT INTO T_General_Statistics (Category, Label, Value)
	SELECT 'Configuration Settings' AS category, 
			PC.Name AS label, PC.Value
	FROM T_Process_Config PC INNER JOIN
		 T_Process_Config_Parameters PCP ON PC.Name = PCP.Name
	ORDER BY PCP.[Function], PC.Name


	-- Modifications
	--
	INSERT INTO T_General_Statistics
	SELECT  'Peptide Modifications' AS category,
			'Mod Count: ' + Convert(varchar(9), Mod_Count) as Label, 
			COUNT(Seq_ID) AS Value
	FROM	T_Sequence
	GROUP BY Mod_Count

/*
 *	The following is more informative, but is very slow to execute
 *
 *	SELECT DISTINCT	'Peptide Modifications' AS category,
 *			V_MasterSeq_Sequence_IDs_with_Mods.Mass_Correction_Tag as Label, 
 *			COUNT(Seq_ID) AS value
 *	FROM	V_MasterSeq_Sequence_IDs_with_Mods
 *	GROUP BY V_MasterSeq_Sequence_IDs_with_Mods.Mass_Correction_Tag
 *
 */

	Return 0



GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

