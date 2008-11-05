/****** Object:  StoredProcedure [dbo].[EditFAD_GANET] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create Procedure dbo.EditFAD_GANET
/****************************************************	
**  Edits row in T_FTICR_Analysis_Description table
**    with new GANET values
**  Optionally records the scan range of the dataset
**  Returns 0 if success; sum of the error numbers on failure
**
**  Date: 05/20/2002 Author: nt
**
**	Updated: 12/30/2003 by mem: Added @TotalScanCount, @ScanStart, @ScanEnd, and @DurationMinutes parameters
****************************************************/
(
	@FAD_Job INT,				--reference to Job column
	@GANETFit FLOAT=Null,		--GANET fit
	@GANETSlope FLOAT=0,		--GANET slope
	@GANETIntercept FLOAT=0,	--GANET intercept
	-- New parameters; defined as Null by default for backwards compatibility
	@TotalScanCount INT=Null,	-- Total scan count
	@ScanStart INT=Null,		-- First scan number (typically 1)
	@ScanEnd INT=Null,			-- Last scan number
	@DurationMinutes FLOAT=0	-- Separation duration, in minutes
)
As
	Set NoCount On
	Declare @ReturnValue int
	Set @ReturnValue = 0
			
	--Update rows in T_FTICR_Analysis_Description matching @FAD_Job
	UPDATE dbo.T_FTICR_Analysis_Description
	SET GANET_Fit=@GANETFit, GANET_Slope=@GANETSlope, 
		GANET_Intercept=@GANETIntercept
	WHERE Job=@FAD_Job	
	--
	Select @ReturnValue = @@ERROR

	-- If @TotalScanCount is defined, then update it
	If IsNull(@TotalScanCount, -1) >=0
	  Begin
		UPDATE dbo.T_FTICR_Analysis_Description
		SET Total_Scans = @TotalScanCount
		WHERE Job=@FAD_Job	
		--
		Select @ReturnValue = @ReturnValue + @@ERROR
	  End

	-- If @ScanStart and @ScanEnd are defined, then update them
	If IsNull(@ScanStart, -1) >=0 And IsNull(@ScanEnd, -1) >=0
	  Begin
		UPDATE dbo.T_FTICR_Analysis_Description
		SET Scan_Start = @ScanStart, Scan_End = @ScanEnd
		WHERE Job=@FAD_Job	
		--
		Select @ReturnValue = @ReturnValue + @@ERROR
	  End

	-- If @DurationMinutes is defined, then update it
	If IsNull(@DurationMinutes, -1) >=0
	  Begin
		UPDATE dbo.T_FTICR_Analysis_Description
		SET Duration = @DurationMinutes
		WHERE Job=@FAD_Job	
		--
		Select @ReturnValue = @ReturnValue + @@ERROR
	  End
	
	Return @ReturnValue

GO
GRANT EXECUTE ON [dbo].[EditFAD_GANET] TO [DMS_SP_User]
GO
GRANT VIEW DEFINITION ON [dbo].[EditFAD_GANET] TO [MTS_DB_Dev]
GO
GRANT VIEW DEFINITION ON [dbo].[EditFAD_GANET] TO [MTS_DB_Lite]
GO
