/****** Object:  Database [PRISM_IFC] ******/
CREATE DATABASE [PRISM_IFC] ON  PRIMARY 
( NAME = N'PRISM_IFC_Data', FILENAME = N'F:\SQLServerData\PRISM_IFC_data.mdf' , SIZE = 6080KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'PRISM_IFC_Log', FILENAME = N'D:\SQLServerData\PRISM_IFC_log.ldf' , SIZE = 1280KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
EXEC dbo.sp_dbcmptlevel @dbname=N'PRISM_IFC', @new_cmptlevel=90
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [PRISM_IFC].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ARITHABORT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [PRISM_IFC] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [PRISM_IFC] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [PRISM_IFC] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [PRISM_IFC] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [PRISM_IFC] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [PRISM_IFC] SET  ENABLE_BROKER 
GO
ALTER DATABASE [PRISM_IFC] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [PRISM_IFC] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [PRISM_IFC] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [PRISM_IFC] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [PRISM_IFC] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [PRISM_IFC] SET  READ_WRITE 
GO
ALTER DATABASE [PRISM_IFC] SET RECOVERY FULL 
GO
ALTER DATABASE [PRISM_IFC] SET  MULTI_USER 
GO
ALTER DATABASE [PRISM_IFC] SET PAGE_VERIFY TORN_PAGE_DETECTION  
GO
ALTER DATABASE [PRISM_IFC] SET DB_CHAINING OFF 
GO
GRANT CONNECT TO [D3E383]
GO
GRANT CONNECT TO [D3J410]
GO
GRANT CONNECT TO [D3L243]
GO
GRANT CONNECT TO [d3m578]
GO
GRANT CONNECT TO [dmswebuser]
GO
GRANT CONNECT TO [msdadmin]
GO
GRANT CONNECT TO [MTAdmin]
GO
GRANT CONNECT TO [MTS_DB_DEV]
GO
GRANT CONNECT TO [MTS_DB_Lite]
GO
GRANT CONNECT TO [MTS_DB_Reader]
GO
GRANT CONNECT TO [MTUser]
GO
GRANT CONNECT TO [pnl\d3m651]
GO
