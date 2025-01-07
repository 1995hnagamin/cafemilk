;;;; Linear Algebra Library

(defpackage :cafemielk/linalg
  (:use :cl :cafemielk/util)
  (:export
   :coo
   :coo-p
   :make-coo
   :csr
   :csr-p
   :make-csr
   :coo->csr
   :dense-matrix
   :dense-matrix-p
   :make-dense-matrix
   :create-empty-dense-matrix
   :dense-matrix-ref
   :matrix-ref
   :mv
   :mv-add!
   :mv-set!
   :rvd
   :rvd-p
   :make-rvd
   :create-empty-rvd
   :get-rvd
   :rvd-find-position
   :rvd-insert
   :rvd-row-count
   :rvd->csr
   :vector-addv!
   :vector-rescale!))
(in-package :cafemielk/linalg)

;;;
;;; Vector operations
;;;

(defun vector-rescale! (y c)
  "y *= c"
  (loop :for i :below (length y) :do
    (setf (aref y i) (* (aref y i) c))))

(defun vector-addv! (y x)
  "y += x"
  (loop :for i :below (length y) :do
    (incf (aref y i) (aref x i))))

(defun vector-rescale-addv! (y c x)
  "y := c * y + x"
  (loop :for i :below (length y) :do
    (setf (aref y i)
          (+ (* (aref y i) c) (aref x i)))))

(defun vector-addcv! (y c x)
  "y += c * x"
  (loop :for i :below (length y) :do
    (incf (aref y i) (* (aref x i) c))))


;;;
;;; Matrix
;;;

(defstruct matrix
  (nrow 0 :type fixnum)
  (ncol 0 :type fixnum))

(defgeneric mv (matrix vector &key element-type)
  (:documentation
   "Returns the matrix-vector product of MATRIX and VECTOR."))

(defgeneric mv-add! (output-vector matrix vector)
  (:documentation
   "Compute the matrix-vector product of MATRIX and VECTOR."))

(defgeneric mv-set! (output-vector matrix vector)
  (:documentation
   "Compute the matrix-vector product of MATRIX and VECTOR.
The result is contained in OUTPUT-VECTOR."))

(defgeneric matrix-ref (matrix i j)
  (:documentation
   "Returns the (I, J) element of MATRIX."))

;;;
;;; Dense Matrix
;;;

(defstruct (dense-matrix (:include matrix))
  (entries nil :type (simple-array * (* *))))

(defmacro dense-matrix-ref (A i j)
  `(aref (dense-matrix-entries ,A) ,i ,j))

(defmethod matrix-ref ((M dense-matrix) i j)
  (dense-matrix-ref M i j))

(defun create-empty-dense-matrix (nrow ncol)
  (make-dense-matrix
   :entries (make-array `(,nrow ,ncol)
                        :initial-element 0)))

(defun dense-matrix-mv-add! (y A x)
  "y += A * x"
  (with-slots (nrow ncol entries) A
    (loop :for i :below nrow :do
      (loop :for j :below ncol :do
        (incf (aref y i)
              (* (matrix-ref A i j)
                 (aref x j)))))))

(defmethod mv-add! (y (A dense-matrix) x)
  (dense-matrix-mv-add! y A x))

(defun dense-matrix-mv (A x &key (element-type t))
  (with-slots (nrow) A
    (let ((y (make-array nrow
                         :initial-element 0
                         :element-type element-type)))
      (dense-matrix-mv-add! y A x)
      y)))

(defmethod mv ((A dense-matrix) x &key (element-type t))
  (dense-matrix-mv A x :element-type element-type))

;;;
;;; COO (coordinate format)
;;;

(defstruct (coo (:include matrix))
  (entries nil :type (array * (*)))
  (rowind nil :type (array * (*)))
  (colind nil :type (array * (*))))

;;;
;;; RVD (row-based vector of dictionaries)
;;;

(defstruct (rvd (:include matrix))
  (index-arrays nil :type (array (array fixnum (*)) (*)))
  (value-arrays nil :type (array (array * (*)) (*))))

(defmacro with-rvd-array-pair ((ia va) (A i) &body body)
  (once-only (A i)
    `(let ((,ia (aref (rvd-index-arrays ,A) ,i))
           (,va (aref (rvd-value-arrays ,A) ,i)))
       ,@body)))

(defun rvd-find-position (ia j)
  (loop
    :for column-index :across ia
    :for position :from 0
    :when (= column-index j) :do (return position)
      :finally (return nil)))

(defun rvd-force-insert (A i j value)
  (with-rvd-array-pair (ia va) (A i)
    (loop
      :with last-index := (progn
                            (vector-push-extend value va)
                            (vector-push-extend j ia))
      :for position :downfrom last-index :above 0
      :until (< (aref ia (1- position))
                (aref ia position))
      :do (rotatef (aref ia (1- position)) (aref ia position))
          (rotatef (aref va (1- position)) (aref va position))
      :finally (return position))))

(defun rvd-add (A i j value)
  (with-rvd-array-pair (ia va) (A i)
    (if-let1 it (rvd-find-position ia j)
             (incf (aref va it) value)
             (rvd-force-insert A i j value))))

(defun rvd-insert (A i j value)
  (with-rvd-array-pair (ia va) (A i)
    (if-let1 it (rvd-find-position ia j)
             (setf (aref va it) value)
             (rvd-force-insert A i j value))))

(defun get-rvd (A i j)
  (with-rvd-array-pair (ia va) (A i)
    (if-let1 it (rvd-find-position ia j)
             (aref va it)
             0)))

(defsetf get-rvd (A i j) (new-value)
  `(rvd-insert ,A ,i ,j ,new-value))

(defun create-nested-array (n &key (element-type t))
    (loop
      :with rows := (make-array n)
      :for i :below n
      :do
         (setf (aref rows i)
               (make-array 0
                           :adjustable t
                           :fill-pointer 0
                           :element-type element-type))
      :finally
         (return rows)))

(defun create-empty-rvd (nrow ncol &key (element-type t))
  (make-rvd
   :nrow nrow
   :ncol ncol
   :index-arrays (create-nested-array nrow :element-type 'fixnum)
   :value-arrays (create-nested-array nrow :element-type element-type)))

(defmethod matrix-ref ((A rvd) i j)
  (get-rvd A i j))

(declaim (inline rvd-row-count))
(defun rvd-row-count (A i)
  (with-rvd-array-pair (ia va) (A i)
    (declare (ignore va))
    (array-dimension ia 0)))

;;;
;;; CSR (compressed sparse row)
;;;

(defstruct (csr (:include matrix))
  (entries nil :type (simple-array * (*)))
  (rowptr nil :type (simple-array fixnum (*)))
  (colind nil :type (simple-array fixnum (*))))

(defun csr-addmv! (y nrow entries rowptr colind x)
  (loop :for i :from 0 :below nrow :do
    (loop :for j :from (aref rowptr i) :below (aref rowptr (1+ i)) :do
      (incf (aref y i)
            (* (aref entries j)
               (aref x (aref colind j)))))))

(defmacro with-expand (symbol expr-list body-expr)
  (with-gensyms (macro-name)
    `(symbol-macrolet ((,symbol ',expr-list))
       (macrolet ((,macro-name () ,body-expr))
         (,macro-name)))))

(defmethod mv-add! (y (A csr) x)
  (with-expand slots (nrow entries rowptr colind)
    `(with-slots ,slots A
       (csr-addmv! y ,@slots x))))

(defun csr-mv-set! (y nrow entries rowptr colind x)
  (loop :for i :from 0 :below nrow :do
    (setf (aref y i) 0))
  (csr-addmv! y nrow entries rowptr colind x))

(defun csr-mv (nrow entries rowptr colind x
               &key (element-type (array-element-type x)))
  (let1 y (make-array nrow :initial-element 0 :element-type element-type)
    (csr-addmv! y nrow entries rowptr colind x)
    y))

(defmethod mv ((A csr) v &key (element-type (array-element-type v)))
  (with-slots (nrow entries rowptr colind) A
    (csr-mv nrow entries rowptr colind v :element-type element-type)))

(defmethod mv-set! (y (A csr) v)
  (with-slots (nrow entries rowptr colind) A
    (csr-mv-set! y nrow entries rowptr colind v)))

(defun csr-ref (A i j)
  (with-slots (entries rowptr colind) A
    (loop :for idx :from (aref rowptr i) :below (aref rowptr (1+ i))
            :thereis (and (= j (aref colind idx))
                          (aref entries idx))
          :finally (return 0))))

(defmethod matrix-ref ((M csr) i j)
  (csr-ref M i j))

(defun rowind->rowptr (rowind nrow)
  (declare (type fixnum nrow))
  (let ((rowptr (make-array (1+ nrow)
                            :element-type 'fixnum))
        (rowind-size (array-dimension rowind 0)))
    (setf (aref rowptr 0) 0)
    (let/goer ((irow 0) (idx 0)) go-loop
      ;; irow: index of the last updated element in rowptr
      ;; idx:  index of the first unseeked element in rowind
      (declare (type fixnum irow idx))
      (cond
        ((= idx rowind-size)
         (loop :for ir :from (1+ irow) :to nrow :do
           (setf (aref rowptr ir) rowind-size))
         rowptr)
        ((> (aref rowind idx) irow)
         (setf (aref rowptr (1+ irow)) idx)
         (go-loop (1+ irow) idx))
        (t
         (go-loop irow (1+ idx)))))))

(defun coo->csr (A &key (element-type t))
  (declare (type coo A))
  (with-slots (nrow ncol entries rowind colind) A
    (make-csr
     :nrow nrow
     :ncol ncol
     :entries (make-array (array-dimension entries 0)
                          :initial-contents entries
                          :element-type element-type)
     :colind (make-array (array-dimension colind 0)
                         :initial-contents colind
                         :element-type 'fixnum)
     :rowptr (rowind->rowptr rowind nrow))))

(defun create-rvd-rowptr (A)
  (with-slots (nrow) A
    (loop :with rowptr := (make-array (1+ nrow)
                                      :initial-element 0
                                      :element-type 'fixnum)
          :for i :below nrow
          :do (setf (aref rowptr (1+ i))
                    (+ (aref rowptr i) (rvd-row-count A i)))
          :finally (return rowptr))))

(defun rvd->csr (A &key (element-type t))
  (declare (type rvd A))
  (with-slots (nrow ncol index-arrays value-arrays) A
    (loop
      :with rowptr := (create-rvd-rowptr A)
      :with size := (aref rowptr nrow)
      :with colind := (make-array size :element-type 'fixnum)
      :with entries := (make-array size :element-type element-type)
      :for i :below nrow
      :do
         (loop :with offset := (aref rowptr i)
               :for idxj :from 0
               :for j :across (aref index-arrays i)
               :for Aij :across (aref value-arrays i)
               :do (setf (aref colind (+ offset idxj)) j)
                   (setf (aref entries (+ offset idxj)) Aij))
      :finally
         (return (make-csr :nrow nrow
                           :ncol ncol
                           :entries entries
                           :colind colind
                           :rowptr rowptr)))))

;;; Local Variables:
;;; mode: lisp
;;; indent-tabs-mode: nil
;;; End:
