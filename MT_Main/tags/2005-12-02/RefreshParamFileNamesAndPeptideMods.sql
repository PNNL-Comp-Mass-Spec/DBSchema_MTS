SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RefreshParamFileNamesAndPeptideMods]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[RefreshParamFileNamesAndPeptideMods]
GO


CREATE PROCEDURE dbo.RefreshParamFileNamesAndPeptideMods
/****************************************************
**
**	Desc: 
**		Updates the entries in T_Peptide_Mod_Param_File_List and
**		T_Peptide_Mod_Global_List using V_DMS_Peptide_Mod_Param_File_List_Import
**		and V_DMS_Peptide_Mod_Param_File_List_Import
**
**		Auth: mem
**		Date: 7/28/2004
**
**		Updated: 09/25/2004 mem - Now posting an entry to the log only if a change was made
**
*****************************************************/
	@UpdateExistingEntries as tinyint=1,
	@message varchar(512)='' Output,
	@PeptideModEntriesAdded int=0 Output,
	@PeptideModEntriesUpdated int=0 Output,
	@ParamFileEntriesAdded int=0 Output,
	@ParamFileEntriesUpdated int=0 Output
AS
	Set NoCount On

	Declare @myError int
	Set @myError = 0

	Declare @myRowCount int
	Set @myRowCount = 0
	
	Set @message = ''
	Set @PeptideModEntriesAdded = 0
	Set @PeptideModEntriesUpdated = 0
	Set @ParamFileEntriesAdded = 0
	Set @ParamFileEntriesUpdated = 0


	set @message = 'Refresh Local Mod Descriptions: '

	Declare @DeletedMessage varchar(128)
	Set @DeletedMessage = ''
	
	If @UpdateExistingEntries = 1
	Begin

		-- ToDo: Look for Param files in T_Peptide_Mod_Param_File_List with a null Param_File_ID
		--       that are now present in V_DMS_Peptide_Mod_Param_File_List_Import
		
		-- Uncomment this after adding the Param_File_ID column to V_DMS_Peptide_Mod_Param_File_List_Import
		UPDATE T_Peptide_Mod_Param_File_List
		SET Param_File_ID = V.Param_File_ID
		FROM V_DMS_Peptide_Mod_Param_File_List_Import AS V INNER JOIN
			T_Peptide_Mod_Param_File_List T ON 
			V.Param_File_Name = T.Parm_File_Name AND 
			V.RefNum = T.RefNum
		WHERE (T.Param_File_ID IS NULL)
		--
		select @myError = @@error, @myRowcount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error updating Param_File_ID values in T_Peptide_Mod_Param_File_List'
			set @myError = 100
			goto Done
		end


		-- Delete extra entries in T_Peptide_Mod_Param_File_List,
		-- but only delete them if they have a Param_File_ID value defined
		--
		DELETE T_Peptide_Mod_Param_File_List
		FROM T_Peptide_Mod_Param_File_List AS T LEFT OUTER JOIN
		    V_DMS_Peptide_Mod_Param_File_List_Import AS V ON T.Parm_File_Name = V.Param_File_Name
		WHERE V.RefNum IS NULL AND
			  NOT T.Param_File_ID IS NULL
		--
		select @myError = @@error, @myRowcount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error deleting extra entries in T_Peptide_Mod_Param_File_List'
			set @myError = 101
			goto Done
		end

		If @myRowcount > 0
			set @DeletedMessage = @DeletedMessage + '; Deleted ' + cast(@myRowcount as varchar(12)) + ' extra from parameter file list'

		-- Delete extra entries in T_Peptide_Mod_Global_List
		--
		DELETE T_Peptide_Mod_Global_List
		FROM	T_Peptide_Mod_Global_List AS T LEFT OUTER JOIN
				 V_DMS_Peptide_Mod_Global_List_Import AS V ON T.Mod_ID = V.Mod_ID
		WHERE	V.Mod_ID IS NULL AND 
				T.Mod_ID NOT IN (SELECT DISTINCT Mod_ID FROM T_Peptide_Mod_Param_File_List)
		--
		select @myError = @@error, @myRowcount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error deleting extra entries from T_Peptide_Mod_Global_List'
			set @myError = 102
			goto Done
		end
		
		If @myRowcount > 0
			set @DeletedMessage = @DeletedMessage + '; Deleted ' + cast(@myRowcount as varchar(12)) + ' extra from mod list'

	End


	-- Append new mods to T_Peptide_Mod_Global_List
	INSERT INTO T_Peptide_Mod_Global_List
		(Mod_ID, Symbol, Description, SD_Flag, 
		 Mass_Correction_Factor, Affected_Residues)
	SELECT Mod_ID, Symbol, Description, SD_Flag, 
	   Mass_Correction_Factor, Affected_Residues
	FROM V_DMS_Peptide_Mod_Global_List_Import
	WHERE (Mod_ID NOT IN
	       (SELECT Mod_ID FROM T_Peptide_Mod_Global_List)
	      )
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error adding new entries to T_Peptide_Mod_Global_List'
		set @myError = 103
		goto Done
	end

	Set @PeptideModEntriesAdded = @myRowCount
	Set @message = @message + cast(@PeptideModEntriesAdded as varchar(12)) + ' entries added to mod global list'

	-- Append new entries to T_Peptide_Mod_Param_File_List
	INSERT INTO T_Peptide_Mod_Param_File_List
		(Parm_File_Name, Local_Symbol, Mod_ID, RefNum, Param_File_ID)
	SELECT	V.Param_File_Name, V.Local_Symbol, V.Mod_ID, V.RefNum, V.Param_File_ID
	FROM V_DMS_Peptide_Mod_Param_File_List_Import AS V LEFT OUTER JOIN
		T_Peptide_Mod_Param_File_List AS T ON 
		V.RefNum = T.RefNum
	WHERE (T.RefNum IS NULL)
	--
	SELECT @myError = @@error, @myRowCount = @@rowcount
	--
	if @myError <> 0
	begin
		set @message = 'Error adding new entries to T_Peptide_Mod_Param_File_List'
		set @myError = 105
		goto Done
	end

	Set @ParamFileEntriesAdded = @myRowCount
	set @message = @message + ' and ' + cast(@ParamFileEntriesAdded as varchar(12)) + ' entries added to parameter file mod list'


	If @UpdateExistingEntries = 1
	Begin
		-- Update existing entries in T_Peptide_Mod_Global_List
		UPDATE T_Peptide_Mod_Global_List
		SET	Symbol = V.Symbol, Description = V.Description, SD_Flag = V.SD_Flag,
			Mass_Correction_Factor = V.Mass_Correction_Factor, Affected_Residues = V.Affected_Residues
		FROM V_DMS_Peptide_Mod_Global_List_Import AS V INNER JOIN
			T_Peptide_Mod_Global_List AS T ON V.Mod_ID = T.Mod_ID
		WHERE V.Symbol <> T.Symbol OR
			V.Description <> T.Description OR
			V.SD_Flag <> T.SD_Flag OR
			V.Mass_Correction_Factor <> T.Mass_Correction_Factor OR
			V.Affected_Residues <> T.Affected_Residues
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error updating existing entries in T_Peptide_Mod_Global_List'
			set @myError = 104
			goto Done
		end

		Set @PeptideModEntriesUpdated = @myRowCount
		If @PeptideModEntriesUpdated > 0
			set @message = @message + '; Updated ' + cast(@PeptideModEntriesUpdated as varchar(12)) + ' in mod list'


		-- Update existing param files in T_Peptide_Mod_Param_File_List
		UPDATE T_Peptide_Mod_Param_File_List
		SET	Parm_File_Name = V.Param_File_Name, Local_Symbol = V.Local_Symbol,
			Mod_ID = V.Mod_ID, Param_File_ID = V.Param_File_ID
		FROM V_DMS_Peptide_Mod_Param_File_List_Import AS V INNER JOIN
			T_Peptide_Mod_Param_File_List AS T ON 
			V.RefNum = T.RefNum
		WHERE V.Param_File_Name <> T.Parm_File_Name OR
			V.Local_Symbol <> T.Local_Symbol OR
			V.Mod_ID <> T.Mod_ID OR
			T.Param_File_ID Is Null AND Not V.Param_File_ID Is Null
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
		--
		if @myError <> 0
		begin
			set @message = 'Error updating existing entries in T_Peptide_Mod_Param_File_List'
			set @myError = 106
			goto Done
		end

		Set @ParamFileEntriesUpdated = @myRowCount
		If @ParamFileEntriesUpdated > 0
			set @message = @message + '; Updated ' + cast(@ParamFileEntriesUpdated as varchar(12)) + ' in parameter file list'

	end
	
	
	If Len(@DeletedMessage) > 0
		Set @message = @message + @DeletedMessage
		
Done:
	-- Only post an entry to the log if a change was made
	If @PeptideModEntriesAdded + @PeptideModEntriesUpdated + @ParamFileEntriesAdded + @ParamFileEntriesUpdated > 0 Or Len(@DeletedMessage) > 0
		execute PostLogEntry 'Normal', @message, 'RefreshParamFileNamesAndPeptideMods'
	
	return @myError

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

