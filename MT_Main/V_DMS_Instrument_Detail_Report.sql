/****** Object:  View [dbo].[V_DMS_Instrument_Detail_Report] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO


CREATE VIEW [dbo].[V_DMS_Instrument_Detail_Report]
AS
SELECT ID, Name, [Assigned Storage], [Assigned Source], 
    Description, Class, Room, Capture, Status, Usage, 
    [Ops Role]
FROM S_V_Instrument_Detail_Report


GO
