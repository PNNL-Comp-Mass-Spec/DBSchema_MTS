/****** Object:  StoredProcedure [dbo].[WebGetQuantitationDescription] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE dbo.WebGetQuantitationDescription
/****************************************************	
**  Desc: Returns a Quantitation Description for editing.
**
**  Return values: 0 if success, otherwise, error code 
**
**  Parameters: Mass Tag DB name and QuantitationID List to process
**
**  Auth: jee
**	Date: 05/12/2004
**		  11/23/2005 mem - Added brackets around @MTDBName as needed to allow for DBs with dashes in the name
**
****************************************************/
(
	@MTDBName varchar(128) = '',
	@QuantitationID varchar(20),	-- Quantitation ID
	@message varchar(512) = '' output
)
AS
	SET NOCOUNT ON
	
	declare @result int
	declare @stmt nvarchar(1024)
	declare @params nvarchar(1024)
	
	set @message = ''
	
	set @stmt = N'SELECT * FROM [' + @MTDBName + N'].dbo.T_Quantitation_Description '
	set @stmt = @stmt + 'WHERE Quantitation_ID = ' + @QuantitationID
	exec (@stmt)

	SELECT @result = @@error
	--
	if @result <> 0 
	begin
		set @message = 'Select failed'
	end

	RETURN @result

GO
GRANT EXECUTE ON [dbo].[WebGetQuantitationDescription] TO [DMS_SP_User] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebGetQuantitationDescription] TO [MTS_DB_Dev] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[WebGetQuantitationDescription] TO [MTS_DB_Lite] AS [dbo]
GO
