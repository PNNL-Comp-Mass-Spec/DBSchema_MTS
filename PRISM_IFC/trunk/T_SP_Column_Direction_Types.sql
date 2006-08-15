/****** Object:  Table [dbo].[T_SP_Column_Direction_Types] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_SP_Column_Direction_Types](
	[Direction_ID] [int] NOT NULL,
	[Direction_Name] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_T_SP_Column_Direction_Types] PRIMARY KEY CLUSTERED 
(
	[Direction_ID] ASC
)WITH FILLFACTOR = 90 ON [PRIMARY]
) ON [PRIMARY]

GO
