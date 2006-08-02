SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[GetFastaFile]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[GetFastaFile]
GO

CREATE Procedure dbo.GetFastaFile


	@Organism varchar(64),
	@DBName varchar(128), 
	@FastaFile varchar(2048) OUTPUT


As
	DECLARE @FastaPath As varchar(2048)
	DECLARE @FastaFileName As varchar(256)
	
	SELECT @FastaPath = og_organismDBPath
	FROM MT_MAIN.dbo.V_DMS_OrganismDB_Folder_Path
	WHERE og_name = @Organism
	
	/* set nocount on */
	return 

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[GetFastaFile]  TO [DMS_SP_User]
GO

