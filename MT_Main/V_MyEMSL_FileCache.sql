/****** Object:  View [dbo].[V_MyEMSL_FileCache] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_MyEMSL_FileCache]
AS
SELECT FileCache.Entry_ID,
       CachePaths.Dataset_ID,
       FileCache.Job,
       FP.Client_Path,
       FP.Server_Path,
       CachePaths.Parent_Path,
	   CachePaths.Dataset_Folder,
       CachePaths.Results_Folder_Name,
       FileCache.Filename,
       FileCache.State,
       CacheState.State_Name,
       FileCache.Queued,
	   FileCache.Optional,
       FileCache.Task_ID
FROM T_MyEMSL_Cache_Paths CachePaths
     INNER JOIN T_MyEMSL_FileCache FileCache
       ON CachePaths.Cache_PathID = FileCache.Cache_PathID
     INNER JOIN T_MyEMSL_Cache_State CacheState
       ON FileCache.State = CacheState.State
     LEFT OUTER JOIN T_Folder_Paths FP
       ON FP.[Function] = 'MyEMSL Cache Folder'


GO
