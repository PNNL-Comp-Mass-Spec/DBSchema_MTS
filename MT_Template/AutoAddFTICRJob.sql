/****** Object:  StoredProcedure [dbo].[AutoAddFTICRJob] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.AutoAddFTICRJob
/****************************************************
**
**	Desc: 
**		Automatically adds an entry to T_FTICR_Analysis_Description (if not yet present)
**
**	Return values: 0 if no error; otherwise error code
**
**	Parameters:
**
**	Auth:	mem
**	Date:	05/04/2011
**			06/29/2011 mem - Now auto-adding the job as a Generic dataset if the job number is not found
**    
*****************************************************/
(
	@Job int,
	@message varchar(512)='' OUTPUT
)
AS
	Set NoCount On

	declare @myRowCount int
	declare @myError int
	set @myRowCount = 0
	set @myError = 0

	Declare @JobList varchar(24)
	Declare @entriesAdded int = 0

	set @message = ''
	
	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try

		If Not Exists (SELECT * FROM T_FTICR_Analysis_Description WHERE Job = @Job)
		Begin
			-----------------------------------------------------------
			-- Try to add the job using ImportNewMSAnalyses
			-----------------------------------------------------------

			Set @JobList = Convert(varchar(24), @Job)
			
			exec ImportNewMSAnalyses @entriesAdded output, @message output, @infoOnly=0, @JobListOverride = @JobList, @PreviewSql=0, @UseCachedDMSDataTables=1

			If Not Exists (SELECT * FROM T_FTICR_Analysis_Description WHERE Job = @Job)
			Begin
				-----------------------------------------------------------
				-- The job still doesn't exist; add it anyway using dummy values
				-----------------------------------------------------------
				
				INSERT INTO T_FTICR_Analysis_Description( Job, Dataset, Dataset_ID, Experiment_Organism, Instrument_Class, Instrument, Analysis_Tool, Parameter_File_Name, 
				                                          Settings_File_Name, Organism_DB_Name, Protein_Collection_List, Protein_Options_List, Vol_Client, Vol_Server, 
				                                          Storage_Path, Dataset_Folder, Results_Folder, Created, Auto_Addition )
				VALUES(@Job,              -- Job
				       'Generic',		  -- Dataset
				       0,				  -- Dataset_ID
				       'Unknown',		  -- Experiment_Organism
				       'Unknown',		  -- Instrument_Class
				       'Unknown',		  -- Instrument
				       'Unknown',		  -- Analysis_Tool
				       '',				  -- Parameter_File_Name
				       '',				  -- Settings_File_Name
				       '',				  -- Organism_DB_Name
				       '',				  -- Protein_Collection_List
				       '',				  -- Protein_Options_List
				       '',				  -- Vol_Client
				       '',				  -- Vol_Server
				       '',				  -- Storage_Path
				       '',				  -- Dataset_Folder
				       '',				  -- Results_Folder
				       GETDATE(),   	  -- Created
					   1)   	          -- Auto_Addition
			End
			
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'AutoAddFTICRJob')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
	End Catch	
	
			
Done:
	Return @myError


GO
GRANT VIEW DEFINITION ON [dbo].[AutoAddFTICRJob] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[AutoAddFTICRJob] TO [MTS_DB_Lite] AS [dbo]
GO
