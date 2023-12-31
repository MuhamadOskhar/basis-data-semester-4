-- Trigger log_data
CREATE TRIGGER tr_log_data ON penyewa AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @id_used INT;
    SELECT @id_used = id_pegawai FROM pegawai WHERE username = 'pemilik1';

    IF (EXISTS(SELECT * FROM Inserted) AND EXISTS (SELECT * FROM Deleted))
    BEGIN
        INSERT INTO log_data (id_pegawai, aktivitas, keterangan, created_at, status_data)
        VALUES (@id_used, 'UPDATE table penyewa', 'Berhasil', SYSDATETIME(), 'aktif');
    END
    ELSE BEGIN
        IF (EXISTS(SELECT * FROM Inserted))
        BEGIN
            INSERT INTO log_data (id_pegawai, aktivitas, keterangan, created_at, status_data)
            VALUES (@id_used, 'INSERT table penyewa', 'Berhasil', SYSDATETIME(), 'aktif');
        END
        ELSE BEGIN
            INSERT INTO log_data (id_pegawai, aktivitas, keterangan, created_at, status_data)
            VALUES (@id_used, 'DELETE table penyewa', 'Berhasil', SYSDATETIME(), 'aktif');
        END
    END
END;

-- Trigger rollback pegawai
CREATE TRIGGER tr_rollback_mobil ON mobil AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @username_pegawai VARCHAR(100);
    SELECT @username_pegawai = pegawai.username FROM pegawai WHERE pegawai.id_pegawai = '4';
    
    IF (@username_pegawai != 'pemilik1')
    BEGIN
        RAISEERROR ('Anda bukan pemilik', 16, 1);
    END
END;

-- Trigger rollback table harga
CREATE TRIGGER tr_rollback_harga ON harga AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @username_pegawai VARCHAR(100);
    SELECT @username_pegawai = pegawai.username FROM pegawai WHERE pegawai.id_pegawai = '4';
    
    IF (@username_pegawai != 'pemilik1')
    BEGIN
        RAISEERROR ('Anda bukan pemilik', 16, 1);
    END
END;

-- Trigger tanggal dibuat
CREATE TRIGGER tr_WaktuDibuat ON penyewa AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE penyewa SET dibuat = SYSDATETIME() WHERE nik IN (SELECT nik FROM Inserted);
END;

CREATE TRIGGER tr_WaktuDibuat1 ON peminjaman AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE peminjaman SET dibuat = SYSDATETIME() WHERE id_peminjaman IN (SELECT id_peminjaman FROM Inserted);
END;

-- Trigger dan procedure rollback table peminjaman
CREATE PROCEDURE sp_tcl_peminjaman 
    @id_mobil INT,
    @id_pegawai INT,
    @nik VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @mobil_id INT, @pegawai_id INT, @penyewa_nik VARCHAR(20);
    SELECT @mobil_id = id_mobil FROM mobil WHERE id_mobil = @id_mobil;
    SELECT @pegawai_id = id_pegawai FROM pegawai WHERE id_pegawai = @id_pegawai;
    SELECT @penyewa_nik = nik FROM penyewa WHERE nik = @nik;
    
    IF (@mobil_id IS NULL OR @pegawai_id IS NULL OR @penyewa_nik IS NULL)
    BEGIN
        RAISEERROR ('Data tidak valid', 16, 1);
    END
    ELSE
    BEGIN
        INSERT INTO peminjaman (id_mobil, id_pegawai, nik, status_peminjaman, keterangan, created_at, status_data)
        VALUES (@id_mobil, @id_pegawai, @nik, 'aktif', 'tidak', SYSDATETIME(), 'aktif');
    END
END;

CREATE TRIGGER tr_trig_pinjam ON peminjaman AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_peminjaman INT, @id_mobil INT, @id_pegawai INT, @nik VARCHAR(20), @uang_muka DECIMAL(10, 2), @id_harga INT, @total_harga DECIMAL(10, 2);
    SELECT @id_peminjaman = id_peminjaman, @id_mobil = id_mobil, @id_pegawai = id_pegawai, @nik = nik, @uang_muka = uang_muka FROM Inserted;
    SELECT @id_harga = mobil.id_harga FROM mobil WHERE mobil.id_mobil = @id_mobil;
    SELECT @total_harga = harga.harga_perhari FROM harga WHERE harga.id_harga = @id_harga;

    EXEC sp_tcl_peminjaman @id_mobil, @id_pegawai, @nik;

    UPDATE peminjaman
    SET total_harga = @total_harga, sisa_pembayaran = @total_harga - @uang_muka, tgl_pinjam = SYSDATETIME()
    WHERE id_peminjaman = @id_peminjaman;
END;

-- Trigger denda
CREATE TRIGGER tr_trig_denda ON peminjaman AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_peminjaman INT, @tgl_pinjam DATE, @tgl_kembali DATE, @lama_pinjam INT, @target DATE;

    SELECT @id_peminjaman = id_peminjaman, @tgl_pinjam = tgl_pinjam, @tgl_kembali = tanggal_kembali, @lama_pinjam = lama_hari_peminjaman FROM Inserted;
    SET @target = DATEADD(day, @lama_pinjam, @tgl_pinjam);

    IF (@target < @tgl_kembali)
    BEGIN
        INSERT INTO denda (id_peminjaman, tanggal_pembayaran, jumlah, created_at, status_data)
        VALUES (@id_peminjaman, SYSDATETIME(), 500000, SYSDATETIME(), 'aktif');
    END;

    UPDATE peminjaman SET status_peminjaman = 'Dikembalikan' WHERE id_peminjaman = @id_peminjaman;
END;
