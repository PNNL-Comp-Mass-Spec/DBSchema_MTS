/****** Object:  StoredProcedure [dbo].[PopulatePeptideDBLocationTable] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.PopulatePeptideDBLocationTable
/****************************************************
**
**	Desc:	Requires that the calling procedure create table #T_Peptide_Database_List
**			 and populate the PeptideDBName or PeptideDBID columns:
**				CREATE TABLE #T_Peptide_Database_List (
**					PeptideDBName varchar(128) NULL,
**					PeptideDBID int NULL,
**					PeptideDBServer varchar(128) NULL,
**					PeptideDBPath varchar(256) NULL
**				)
**
**			This procedure will fill in the other two columns (server and Name or ID)
**			Note that if @PreferDBName = 1, then first tries to update values using PeptideDBName;
**			 otherwise, PeptideDBID is used first
**
**			Will also update PeptideDBPath such that it simply contains the DB name (surrounded by square brackets)
**			 if the DB resides on this server
**			If the DB does not reside on this server, then updates PeptideDBPath to include server name and DB name, e.g. TheServer.[PT_None_A67]
**
**	Return values: 0: success, otherwise, error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	09/19/2006
**    
*****************************************************/
(
	@PreferDBName tinyint = 1,			-- Set to 1 so that PeptideDBName is initially used to determine PeptideDBID; set to 0 to initially try PeptideDBID
	@message varchar(512) = '' output
)
AS
	Set NoCount on
	 
	declare @myRowCount int	
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	set @PreferDBName = IsNull(@PreferDBName, 1)
	set @message = ''
	
	Declare @MatchCount int
	Declare @LoopCountTotal int
	Declare @Iteration int
	Declare @TestingDBName tinyint
	
	If @PreferDBName = 0
		Set @TestingDBName = 0
	Else
		Set @TestingDBName = 1
		
	Set @LoopCountTotal = 2
	Set @Iteration = 0
	While @Iteration < @LoopCountTotal
	Begin -- <a>
	
		If @TestingDBName = 1
		Begin -- <b1>
			---------------------------------------------------
			-- Assume PeptideDBName is defined; use this to determine PeptideDBID and PeptideDBServer
			-- First examine T_Peptide_Database_List, filtering on state < 15
			---------------------------------------------------
			--
			UPDATE #T_Peptide_Database_List
			SET PeptideDBServer = @@ServerName,
				PeptideDBID = Src.PDB_ID,
				PeptideDBName = Src.PDB_Name
			FROM #T_Peptide_Database_List Target INNER JOIN 
				T_Peptide_Database_List Src ON Target.PeptideDBName = Src.PDB_Name AND Src.PDB_State < 15
			WHERE Target.PeptideDBServer Is Null OR Target.PeptideDBID Is Null
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @myError <> 0
			Begin
				Set @message = 'Error updating #T_Peptide_Database_List using T_Peptide_Database_List'
				Goto Done
			End

			---------------------------------------------------
			-- See if any rows in #T_Peptide_Database_List have null values for 
			-- PeptideDBServer or PeptideDBID
			---------------------------------------------------
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM #T_Peptide_Database_List
			WHERE PeptideDBServer Is Null OR PeptideDBID Is Null
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount

			If @MatchCount > 0
			Begin -- <c>
				---------------------------------------------------
				-- Use MTS_Master on Pogo to determine server name and DB ID
				---------------------------------------------------
				UPDATE #T_Peptide_Database_List
				SET PeptideDBServer = Src.Server_Name,
					PeptideDBID = Src.Peptide_DB_ID,
					PeptideDBName = Src.Peptide_DB_Name
				FROM #T_Peptide_Database_List Target INNER JOIN 
					 V_MTS_PT_DBs Src ON Target.PeptideDBName = Src.Peptide_DB_Name
				WHERE Target.PeptideDBServer Is Null OR Target.PeptideDBID Is Null
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myError <> 0
				Begin
					Set @message = 'Error updating #T_Peptide_Database_List using V_MTS_PT_DBs'
					Goto Done
				End
			End -- </c>
		End -- </b1>
		Else
		Begin -- <b2>
			---------------------------------------------------
			-- Assume PeptideDBID is defined; use this to determine PeptideDBName and PeptideDBServer
			-- First examine T_Peptide_Database_List, filtering on state < 15
			---------------------------------------------------
			--
			UPDATE #T_Peptide_Database_List
			SET PeptideDBServer = @@ServerName,
				PeptideDBName = Src.PDB_Name
			FROM #T_Peptide_Database_List Target INNER JOIN 
				T_Peptide_Database_List Src ON Target.PeptideDBID = Src.PDB_ID AND Src.PDB_State < 15
			WHERE Target.PeptideDBServer Is Null OR Target.PeptideDBName Is Null
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @myError <> 0
			Begin
				Set @message = 'Error updating #T_Peptide_Database_List using T_Peptide_Database_List'
				Goto Done
			End

			---------------------------------------------------
			-- See if any rows in #T_Peptide_Database_List have null values for 
			-- PeptideDBServer or PeptideDBName
			---------------------------------------------------
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM #T_Peptide_Database_List
			WHERE PeptideDBServer Is Null OR PeptideDBName Is Null
			--
			SELECT @myError = @@error, @myRowCount = @@rowcount
			
			If @MatchCount > 0
			Begin -- <c>
				---------------------------------------------------
				-- Use MTS_Master on Pogo to determine server name and DB name
				---------------------------------------------------
				UPDATE #T_Peptide_Database_List
				SET PeptideDBServer = Src.Server_Name,
					PeptideDBName = Src.Peptide_DB_Name
				FROM #T_Peptide_Database_List Target INNER JOIN 
					 V_MTS_PT_DBs Src ON Target.PeptideDBID = Src.Peptide_DB_ID
				WHERE Target.PeptideDBServer Is Null OR Target.PeptideDBName Is Null
				--
				SELECT @myError = @@error, @myRowCount = @@rowcount

				If @myError <> 0
				Begin
					Set @message = 'Error updating #T_Peptide_Database_List using V_MTS_PT_DBs'
					Goto Done
				End
			End -- </c>
		End -- </b2>

		If @TestingDBName = 0
			Set @TestingDBName = 1
		Else
			Set @TestingDBName = 0
			
		Set @Iteration = @Iteration + 1

		If @Iteration < @LoopCountTotal
		Begin
			---------------------------------------------------
			-- See if any rows still have null values
			-- Exit the loop if all rows have data
			---------------------------------------------------
			Set @MatchCount = 0
			SELECT @MatchCount = COUNT(*)
			FROM #T_Peptide_Database_List
			WHERE PeptideDBServer Is Null OR PeptideDBID Is Null OR PeptideDBName Is Null
			
			If @MatchCount = 0
				Set @Iteration = @LoopCountTotal+1
		End

	End -- </a>

	---------------------------------------------------
	-- Populate the PeptideDBPath field
	---------------------------------------------------
	--
	UPDATE #T_Peptide_Database_List
	SET PeptideDBPath = '[' + PeptideDBName + ']'
	WHERE Upper(PeptideDBServer) = Upper(@@ServerName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

	UPDATE #T_Peptide_Database_List
	SET PeptideDBPath = PeptideDBServer + '.[' + PeptideDBName + ']'
	WHERE Upper(PeptideDBServer) <> Upper(@@ServerName)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount

			
Done:
	Return @myError


GO
GRANT EXECUTE ON [dbo].[PopulatePeptideDBLocationTable] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PopulatePeptideDBLocationTable] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[PopulatePeptideDBLocationTable] TO [MTS_DB_Lite] AS [dbo]
GO
