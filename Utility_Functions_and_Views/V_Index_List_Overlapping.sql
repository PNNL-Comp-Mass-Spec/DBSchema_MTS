if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[V_Index_List_Overlapping]') and OBJECTPROPERTY(id, N'IsView') = 1)
drop view [dbo].[V_Index_List_Overlapping]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

CREATE VIEW dbo.V_Index_List_Overlapping
AS
SELECT TOP 100 PERCENT l1.TableName, l1.IndexName, 
    l2.IndexName AS overlappingIndex, l1.col1, l1.col2, l1.col3, 
    l1.col4, l1.col5, l1.col6, l1.dpages, l1.used, l1.rowcnt
FROM dbo.V_Index_List l1 INNER JOIN
    dbo.V_Index_List l2 ON l1.TableName = l2.TableName AND 
    l1.IndexName <> l2.IndexName AND l1.col1 = l2.col1 AND 
    (l1.col2 IS NULL OR
    l2.col2 IS NULL OR
    l1.col2 = l2.col2) AND (l1.col3 IS NULL OR
    l2.col3 IS NULL OR
    l1.col3 = l2.col3) AND (l1.col4 IS NULL OR
    l2.col4 IS NULL OR
    l1.col4 = l2.col4) AND (l1.col5 IS NULL OR
    l2.col5 IS NULL OR
    l1.col5 = l2.col5) AND (l1.col6 IS NULL OR
    l2.col6 IS NULL OR
    l1.col6 = l2.col6)
ORDER BY l1.TableName, l1.IndexName


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


exec sp_addextendedproperty N'MS_DiagramPane1', N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[18] 4[15] 2[48] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1[50] 2[25] 3) )"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4[30] 2[21] 3) )"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1 [56] 4 [18] 2))"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 3
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "l1"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 239
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "l2"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 239
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      RowHeights = 260
      Begin ColumnWidths = 13
         Width = 284
         Width = 1440
         Width = 1440
         Width = 2745
         Width = 1440
         Width = 1440
         Width = 1440
         Width = 1440
         Width = 1440
         Width = 1440
         Width = 1440
         Width = 1440
         Width = 1440
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', N'user', N'dbo', N'view', N'V_Index_List_Overlapping'
GO
exec sp_addextendedproperty N'MS_DiagramPaneCount', 1, N'user', N'dbo', N'view', N'V_Index_List_Overlapping'

GO

