if exists (select * from dbo.sysobjects where id = object_id(N'[T_Histogram_Cache_Data]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [T_Histogram_Cache_Data]
GO

CREATE TABLE [T_Histogram_Cache_Data] (
	[Histogram_Cache_ID] [int] NOT NULL ,
	[Bin] [float] NOT NULL ,
	[Frequency] [int] NOT NULL ,
	CONSTRAINT [PK_T_Histogram_Cache_Data] PRIMARY KEY  CLUSTERED 
	(
		[Histogram_Cache_ID],
		[Bin]
	)  ON [PRIMARY] ,
	CONSTRAINT [FK_T_Histogram_Cache_Data_T_Histogram_Cache] FOREIGN KEY 
	(
		[Histogram_Cache_ID]
	) REFERENCES [T_Histogram_Cache] (
		[Histogram_Cache_ID]
	) ON DELETE CASCADE 
) ON [PRIMARY]
GO


