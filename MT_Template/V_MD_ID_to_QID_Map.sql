/****** Object:  View [dbo].[V_MD_ID_to_QID_Map] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MD_ID_to_QID_Map]
AS
-- Choose the best Quantitation_ID for each MD_ID
-- Sort by Quantitation_State in the Row_Number() function so we favor QIDs in state 1 or 2 over state 3 (success) or 5 (superseded)
-- Note that stored procedure SetPeakMatchingActivityValuesToComplete in Prism_RPT uses V_PM_Results_MDID_and_QID to associate a Task_ID with a QID; V_PM_Results_MDID_and_QID references this view
-- Favor single-member QIDs over multi-member QIDs
-- Favor larger QIDs values
SELECT QMDIDs.MD_ID,
       QMDIDs.Quantitation_ID,
       InnerQ.QID_Member_Count,
       Row_Number() OVER ( PARTITION BY QMDIDs.MD_ID 
                           ORDER BY InnerQ.QID_Member_Count, QD.Quantitation_State, InnerQ.Quantitation_ID DESC ) AS MemberCountRank
FROM T_Quantitation_MDIDs QMDIDs
     INNER JOIN ( SELECT Quantitation_ID,
                         COUNT(*) AS QID_Member_Count
                  FROM T_Quantitation_MDIDs QMDIDs
                  GROUP BY Quantitation_ID ) InnerQ
       ON QMDIDs.Quantitation_ID = InnerQ.Quantitation_ID
     INNER JOIN T_Quantitation_Description QD
       ON QMDIDs.Quantitation_ID = QD.Quantitation_ID
WHERE QD.Quantitation_State IN (1,2,3,5)


GO
