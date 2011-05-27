/****** Object:  StoredProcedure [dbo].[GetAllowedDatasetAcqLength] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure dbo.GetAllowedDatasetAcqLength
/****************************************************	
**  Desc:	Examines T_Process_Config to determine the allowed
**			range of dataset acquisition lengths
**
**  Return values:	0 if success, otherwise, error code 
**
**  Auth:	mem
**	Date:	07/13/2010 mem - Initial version
**
****************************************************/
(
	@AcqLengthMinimum real = 0 output,
	@AcqLengthMaximum real = 0 output,
	@AcqLengthFilterEnabled tinyint = 0 output,
	@LogErrors tinyint = 1,
	@message varchar(512)='' output
)
AS
	Set NoCount On

	Declare @myError int
	Declare @myRowcount int
	Set @myRowcount = 0
	Set @myError = 0

	Declare @AcqLengthSpecs varchar(128)
	Declare @CommaLoc int

	declare @CallingProcName varchar(128)
	declare @CurrentLocation varchar(128)
	Set @CurrentLocation = 'Start'

	Begin Try
		
		-------------------------------------------------
		-- Validate the inputs
		-------------------------------------------------	

		Set @AcqLengthMinimum = -1
		Set @AcqLengthMaximum = 1e6
		Set @AcqLengthFilterEnabled = 0

		Set @LogErrors = IsNull(@LogErrors, 1)

		Set @message = ''

		-------------------------------------------------
		-- Look for 'Dataset_Acq_Length_Range' in T_Process_Config
		-------------------------------------------------	

		Set @CurrentLocation = 'Query T_Process_Config'

		Set @AcqLengthSpecs = ''
		
		SELECT @AcqLengthSpecs = Value
		FROM T_Process_Config
		WHERE [Name] = 'Dataset_Acq_Length_Range'
		--
		SELECT @myError = @@error, @myRowCount = @@rowcount
	
		If LTrim(RTrim(@AcqLengthSpecs)) <> ''
		Begin	
			Set @AcqLengthFilterEnabled = 1

			If @AcqLengthSpecs LIKE '%,%'
			Begin
				-- Split on the comma
				Set @CurrentLocation = 'Split on comma'

				Set @CommaLoc = CharIndex(',', @AcqLengthSpecs)
				
				If NOT @AcqLengthSpecs LIKE ',%'
					Set @AcqLengthMinimum = Convert(real, SUBSTRING(@AcqLengthSpecs, 1, @CommaLoc-1))

				If NOT @AcqLengthSpecs LIKE '%,'
					Set @AcqLengthMaximum = Convert(real, SUBSTRING(@AcqLengthSpecs, @CommaLoc+1, LEN(@AcqLengthSpecs)))
			End
			Else
			Begin
				
				-- No comma; try to convert to a number
				Set @CurrentLocation = 'Parse setting (no comma)'

				If IsNumeric(@AcqLengthSpecs) <> 0
				Begin
					Set @AcqLengthMinimum = Convert(real, @AcqLengthSpecs)
					
					-- Define the Minimum and Maximum as +/- 20% from the specified value
					Set @AcqLengthMaximum = @AcqLengthMinimum * 1.2
					Set @AcqLengthMinimum = @AcqLengthMinimum * 0.8
				End
				Else
				Begin
					Set @message = 'Dataset_Acq_Length_Range defined in T_Process_Config is not numeric: ' + @AcqLengthSpecs 
					Set @myError = 50000
										
					If @LogErrors = 0
					Begin
						SELECT @message AS ErrorMessage
						Goto DoneSkipLog
					End
					Else
						Goto Done
				End
			End
		End

	End Try
	Begin Catch
		-- Error caught; log the error then abort processing
		Set @CallingProcName = IsNull(ERROR_PROCEDURE(), 'GetAllowedDatasetAcqLength')
		exec LocalErrorHandler  @CallingProcName, @CurrentLocation, @LogError = 1, @LogWarningErrorList = '',
								@ErrorNum = @myError output, @message = @message output
		Goto DoneSkipLog
	End Catch
				
Done:
	-----------------------------------------------------------
	-- Done processing
	-----------------------------------------------------------
		
	If @myError <> 0 
	Begin
		Execute PostLogEntry 'Error', @message, 'GetAllowedDatasetAcqLength'
		Print @message
	End

DoneSkipLog:	
	Return @myError


GO
