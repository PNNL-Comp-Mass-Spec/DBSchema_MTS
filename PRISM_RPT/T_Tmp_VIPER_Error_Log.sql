/****** Object:  Table [dbo].[T_Tmp_VIPER_Error_Log] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Tmp_VIPER_Error_Log](
	[Computer] [varchar](7) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Date] [datetime] NULL,
	[Source] [varchar](40) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Error_Code] [int] NULL
) ON [PRIMARY]

GO
