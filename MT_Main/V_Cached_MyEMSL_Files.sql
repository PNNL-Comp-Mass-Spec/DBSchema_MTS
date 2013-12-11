/****** Object:  View [dbo].[V_Cached_MyEMSL_Files] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create VIEW V_Cached_MyEMSL_Files
AS
SELECT FileCache.Task_ID,
       FileCache.Entry_ID,
       CachePaths.Dataset_ID,
       FileCache.Job,
       FP.Client_Path,
       FP.Server_Path,
       CachePaths.Parent_Path,
       CachePaths.Results_Folder_Name,
       FileCache.Filename,
       FileCache.State,
       CacheState.State_Name
FROM T_MyEMSL_Cache_Paths CachePaths
     INNER JOIN T_MyEMSL_FileCache FileCache
       ON CachePaths.Cache_PathID = FileCache.Cache_PathID
     INNER JOIN T_MyEMSL_Cache_State CacheState
       ON FileCache.State = CacheState.State
     LEFT OUTER JOIN T_Folder_Paths FP
       ON FP.[Function] = 'MyEMSL Cache Folder'

GO
