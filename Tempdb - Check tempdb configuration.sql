-------------------------------------------------
		-- tempDB data file configurations subsection
		-------------------------------------------------
		SET NOCOUNT ON;
		RAISERROR (N'Starting tempDB data file configurations', 10, 1) WITH NOWAIT
		DECLARE @tdb_files int, @online_count int, @filesizes SMALLINT, @tdb_files_setpercent int, @TempdbOnC NVARCHAR(4000), @datasizeGB NUMERIC(18,2)
		SELECT @tdb_files = COUNT(physical_name), @datasizeGB = SUM(size * 8) / 1024. / 1024. FROM sys.master_files (NOLOCK) WHERE database_id = 2 AND [type] = 0;
		SELECT @tdb_files_setpercent = COUNT(*) FROM tempdb.sys.database_files WHERE is_percent_growth = 1
		SELECT @online_count = COUNT(cpu_id) FROM sys.dm_os_schedulers WHERE is_online = 1 AND scheduler_id < 255 AND parent_node_id < 64;
		SELECT @filesizes = COUNT(DISTINCT size) FROM tempdb.sys.database_files WHERE [type] = 0;
		SELECT @TempdbOnC = physical_name FROM tempdb.sys.database_files WHERE physical_name LIKE 'C:%';
		DECLARE @tracestatus TABLE (TraceFlag NVARCHAR(40), [Status] tinyint, [Global] tinyint, [Session] tinyint);
		
		DECLARE @sqlmajorver int
		SELECT @sqlmajorver = CONVERT(int, (@@microsoftversion / 0x1000000) & 0xff);
		
		DECLARE @Tmp TABLE (ConfigCheckName VARCHAR(200), CheckStatus VARCHAR(8000))
		
		
		INSERT INTO @tracestatus 
		EXEC ('DBCC TRACESTATUS WITH NO_INFOMSGS')
		
			IF EXISTS (SELECT TraceFlag FROM @tracestatus WHERE [Global] = 1 AND TraceFlag = 1117)
			BEGIN
		   INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
				 SELECT 'Check - TF 1117 Enabled' AS ConfigCheckName,
				 CASE WHEN @sqlmajorver >= 13 --SQL 2016
					  THEN 'INFORMATION - TF1117 is not needed in SQL 2016 and higher versions'
					  ELSE 'OK - TF1117 is enabled and will autogrow all files at the same time, this TF affects all databases.' 
				 END AS CheckStatus
				 FROM @tracestatus 
				 WHERE [Global] = 1 AND TraceFlag = 1117
			END;
			
			IF NOT EXISTS (SELECT TraceFlag FROM @tracestatus WHERE [Global] = 1 AND TraceFlag = 1117)
				AND (@sqlmajorver < 13)
			BEGIN
		   INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
				 SELECT 'Check - TF 1117 Enabled' AS ConfigCheckName,
						   'FAILED - Consider enabling TF1117 to autogrow all files at the same time.' AS CheckStatus;
			END;
		
			IF NOT EXISTS (SELECT TraceFlag FROM @tracestatus WHERE [Global] = 1 AND TraceFlag = 1117)
				AND (@sqlmajorver >= 13)
			BEGIN
		   INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
				 SELECT 'Check - TF 1117 Enabled' AS ConfigCheckName,
						   'INFORMATION - SQL version is >= 2016, skipping this check.' AS CheckStatus;
			END;
			
			IF EXISTS (SELECT TraceFlag FROM @tracestatus WHERE [Global] = 1 AND TraceFlag = 1118)
			BEGIN
		   INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
				 SELECT 'Check - TF 1118 Enabled' AS ConfigCheckName,
				 CASE 
			 WHEN @sqlmajorver >= 13 --SQL 2016
					  THEN 'INFORMATION - TF1118 is not needed in SQL 2016 and higher versions'
					  ELSE 'OK - TF1118 forces uniform extent allocations instead of mixed page allocations.'
				 END AS CheckStatus
				 FROM @tracestatus 
				 WHERE [Global] = 1 AND TraceFlag = 1118
			END;
			
			IF NOT EXISTS (SELECT TraceFlag FROM @tracestatus WHERE [Global] = 1 AND TraceFlag = 1118)
				AND (@sqlmajorver < 13)
			BEGIN
		   INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
				 SELECT 'Check - TF 1118 Enabled' AS ConfigCheckName,
						   'FAILED - Consider enabling TF1118 to force uniform extent allocations instead of mixed page allocations.' AS CheckStatus;
			END;
		
			IF NOT EXISTS (SELECT TraceFlag FROM @tracestatus WHERE [Global] = 1 AND TraceFlag = 1117)
				AND (@sqlmajorver >= 13)
			BEGIN
		   INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
				 SELECT 'Check - TF 1118 Enabled' AS ConfigCheckName,
						   'INFORMATION - SQL version is >= 2016, skipping this check.' AS CheckStatus;
			END;
		 
		 INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		 SELECT 
		   'Check - Number of data files to scheduler ratio' AS ConfigCheckName,
					'INFORMATION - There are ' + CONVERT(VARCHAR, @tdb_files) + ' data files and ' + CONVERT(VARCHAR, @online_count) +' online schedulers.' AS CheckStatus;
		  INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		  SELECT 
			  'Check - Auto growth is the same for all files' AS ConfigCheckName,
			  CASE 
				WHEN (SELECT COUNT(DISTINCT growth) FROM sys.master_files WHERE [database_id] = 2 AND [type] = 0) > 1  THEN 'FAILED - Some tempDB data files have different auto growth settings.'
				ELSE 'OK - Auto growth is the same for all files.' 
			  END AS CheckStatus;
		
		  INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		  SELECT 
			  'Check - File growth set to percent' AS ConfigCheckName,
			  CASE 
				WHEN @tdb_files_setpercent >= 1 THEN 'FAILED - ' + CONVERT(VARCHAR, @tdb_files_setpercent) + ' file(s) has autogrowth set to percent. Best practice is all files have an explicit growth value.' 
				ELSE 'OK - All files have an explicit growth value.' 
			  END AS CheckStatus;
			
		  INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		  SELECT 
			  'Check - Sizes of all the tempdb data files are the same' AS ConfigCheckName,
			  CASE 
				WHEN @filesizes > 1 THEN 'FAILED - Data file sizes do not match.' 
				ELSE 'OK - Sizes of all the tempdb data files are the same.' 
			  END AS CheckStatus;
		
		  INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		  SELECT 
			  'Check - Number of data files is multiple of 4' AS ConfigCheckName,
			  CASE 
				WHEN @tdb_files % 4 > 0 THEN 'FAILED - Number of data files (' + CONVERT(VARCHAR, @tdb_files) + ') is not multiple of 4.' 
				ELSE 'OK - Number of data files (' + CONVERT(VARCHAR, @tdb_files) + ') is multiple of 4.' 
			  END AS CheckStatus;
		
		  INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		  SELECT 
			  'Check - Tempdb located on the C:\' AS ConfigCheckName,
			  CASE 
				WHEN ISNULL(@TempdbOnC, '') <> '' THEN 'FAILED - There are tempdb files (' + CONVERT(NVARCHAR(4000), @TempdbOnC) + ') stored on C:\.' 
				ELSE 'OK - There are no tempdb files stored on C:\' 
			  END AS CheckStatus;
		
		  INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		  SELECT 
			  'Check - Pre-size tempdb files to avoid auto growths' AS ConfigCheckName,
			  CASE 
				WHEN @datasizeGB <= 10 /*10GB*/ THEN 'FAILED - Tempdb data size (' + CONVERT(VARCHAR, @datasizeGB) + ' GB) is too small (<=10 GB) , are you sure this was pre-sized ?' 
				ELSE 'OK - Tempdb size (' + CONVERT(VARCHAR, @datasizeGB) + ' GB) looks ok.' 
			  END AS CheckStatus;
		
    DECLARE @sqlminorver INT
    SELECT @sqlminorver = CONVERT(INT, (@@microsoftversion / 0x10000) & 0xff);
    IF (@sqlmajorver >= 11) OR (@sqlmajorver = 10 AND @sqlminorver = 50)
    BEGIN
		    INSERT INTO @Tmp(ConfigCheckName, CheckStatus)
		    SELECT 
			    'Check - Stored tempdb files on disk that differ from user databases' AS ConfigCheckName,
			    CASE 
				  WHEN EXISTS(SELECT t1.physical_name, vs1.volume_mount_point
									  FROM sys.master_files t1 (NOLOCK)
							   CROSS APPLY sys.dm_os_volume_stats(t1.database_id, t1.file_id) AS vs1
								  WHERE t1.[database_id] = 2 AND t1.[type] = 0
							     AND EXISTS(SELECT * FROM sys.master_files t2 
										     CROSS APPLY sys.dm_os_volume_stats(t2.database_id, t2.file_id) AS vs2
										     WHERE DB_NAME(t2.database_id) NOT IN ('master', 'model', 'msdb', 'tempdb')
											   AND vs1.logical_volume_name = vs2.logical_volume_name)) THEN 'FAILED - TempDB is on the same disk as other user DBs.' 
				  ELSE 'OK - Tempdb files stored on disk that differ from user DBs.' 
			    END AS CheckStatus;
    END
		
		SELECT * FROM @Tmp