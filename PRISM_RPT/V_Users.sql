/****** Object:  View [dbo].[V_Users] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_Users]
AS
SELECT U_PRN, U_Name, U_HID, ID, U_Status, U_Access_Lists, U_email, U_domain, U_netid, U_active, U_Update
FROM Gigasax.DMS5.dbo.T_Users


GO
